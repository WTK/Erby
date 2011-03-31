module ERBY
  class NodeConnection < EM::Connection
    include EM::Deferrable

    STATE_DISCONNECTED = -1
    STATE_HANDSHAKE_RECV_STATUS = 2
    STATE_HANDSHAKE_RECV_CHALLENGE = 4
    STATE_HANDSHAKE_RECV_CHALLENGE_ACK = 6
    STATE_CONNECTED = 7

    attr_accessor :destnode, :mod, :fun, :args, :port, :name, :cookie,
                    :state, :response_data, :packet_len_size, :challenge_to_peer

    def initialize *init_data
      @args = []
      data = init_data[0]
      data.each do |attr, value|
        send "#{attr}=", value
      end if data.respond_to? :each
      @state = STATE_DISCONNECTED
      @packet_len_size = 2
      @response_data = ''
      super
    end

    def connection_completed
      @state = STATE_HANDSHAKE_RECV_STATUS
      # send our (local) nodename to start handshake process
      send_name
    end

    # This method is invoked by EM whenever we got new data on connection
    def receive_data data
      #puts "receive data #{data.dump} |(#{data.length})"
      if data.length == 0
        close
      end
      @response_data += data
      remaining_unhandled_data = handle_data @response_data
      @response_data = remaining_unhandled_data
    end

    def unbind
      fail
    end

    def rpc args
      puts "do rpc to: #{@mod}:#{@fun}, with args: #{args.inspect}"
    end

    private
    def close
      @state = STATE_DISCONNECTED
      unbind
    end

    def handle_data data
      remaining_data = data

      while true
        remaining_data_length = remaining_data.length
        return remaining_data if remaining_data_length < @packet_len_size

        if @packet_len_size == 2
          packet_len = Erlang::Decoder.new(remaining_data[0...2]).read_int2
          packet_offset = 2
        else
          packet_len = Erlang::Decoder.new(remaining_data[0...4]).read_int4
          packet_offset = 4
        end

        if remaining_data_length < @packet_len_size + packet_len
          return remaining_data
        end

        packet_data = remaining_data[packet_offset...(packet_offset+packet_len)]
        handle_packet packet_data
        remaining_data = remaining_data[(packet_offset+packet_len)..remaining_data_length]
      end
    end

    def handle_packet packet
      #puts "handle packet #{packet.dump}"
      case @state
        when STATE_HANDSHAKE_RECV_STATUS then
          raise "Didn't received valid status information on handshake." if packet[0..0] != 's'          
          status = packet[1..packet.length]
          #puts "status=#{status.dump}"
          if status == 'ok' or status == 'ok_simultaneous'
            @state = STATE_HANDSHAKE_RECV_CHALLENGE
          elsif status == 'nok' or status == 'not_allowed'
            raise "Handshake failed. Received \"#{status.dump}\" status."
          elsif status == 'alive'
            send_alive true
            @state = STATE_HANDSHAKE_RECV_CHALLENGE
          else
            raise "Unexpected handshake status: \"#{status.dump}\". | #{status.length}"
          end
        when STATE_HANDSHAKE_RECV_CHALLENGE then
          raise "Expected \"n\", got: \"#{packet[0..0].dump}\"." if packet[0..0] != 'n'
          @state = STATE_HANDSHAKE_RECV_CHALLENGE_ACK

          #peer_version = Erlang::Decoder.new(packet[1...3]).read_int2
          #peer_flags = Erlang::Decoder.new(packet[3...7]).read_int4
          challenge = Erlang::Decoder.new(packet[7...11]).read_int4
          #peer_name = packet[11..packet.length]

          send_challenge_reply challenge
        when STATE_HANDSHAKE_RECV_CHALLENGE_ACK then
          raise "Unexpected message. Expected \"a\", got: \"#{packet[0..0].dump}\"." if packet[0..0] != 'a'
          digest = packet[1..packet.length]
          if digest_correct? digest
            @packet_len_size = 4
            @state = STATE_CONNECTED
            succeed
          else
            raise "Connection attempt to disallowed node."
          end
        when STATE_CONNECTED then
          send_tick and return if packet.length == 0
      else
        raise "Unknown state to handle packet - \"#{packet.dump}\"."
      end
    end

    def digest_correct? digest
      digest == digest(@challenge_to_peer)
    end

    def send_alive value_to_send
      send_handshake_packet(value_to_send ? "true" : "false")
    end

    # Send tick to assure remote node that we are still alive.
    # Tick is an empty string.
    # Final result that is send back to erlang node is \000\000\000\000
    # which is length of tick (empty string, so: 0) encoded using four bytes,
    # plus the tick itself (which is an empty string).
    # By default tick is send every 15 seconds of inactivity.
    def send_tick
      msg = Erlang::Encoder.new
      msg.write_4 0
      msg.write ''
      send_data msg
    end

    def send_name
      msg = Erlang::Encoder.new
      msg.int2 @name.length + 7 # plus seven because of other
      # node type
      msg.int1 110
      # distChoose
      msg.int2 5
      # flags
      msg.int4 4|256|1024|2048
      # node name
      msg.write @name
      send_data msg
    end

    def send_challenge_reply challenge
      @challenge_to_peer = gen_challenge
      msg = Erlang::Encoder.new
      msg.write "r"
      msg.int4 @challenge_to_peer
      msg.write digest(challenge)
      send_handshake_packet msg.to_s
    end

    def send_handshake_packet packet
      msg = Erlang::Encoder.new
      msg.int2 packet.length
      msg.write packet
      send_data msg
    end

    def gen_challenge
      Integer(rand() * 0x7fffffff)
    end

    def digest challenge
      d = Digest::MD5.new
      d << @cookie
      d << challenge.to_s
      d.digest
    end
  end

  # Class that serves as wrapper that makes possible to make
  # calls like that: ERBY.module_name.rpc_function_name(arg1, arg2, argn)
  class ErlangModuleHelper
    attr_accessor :module
    def initialize mod
      @module = mod
    end

    def method_missing fun, *args
      ERBY.call "#{@module}:#{fun}", args
    end
  end

  def self.call calee, args=nil
    mod,fun = mod_and_fun calee

    config = ERBY::config.get_config_for mod
    port = Epmd.port_for mod

    rpcsetup = proc {
      EM.run do
        conn = EM.connect config[:server], port, NodeConnection,
                           :destnode => config[:node],
                           :mod => mod,
                           :cookie => config[:cookie],
                           :fun => fun,
                           :port => port,
                           :name => "erby_client_#{$$.to_s}@#{Socket.gethostname}"
        conn.callback do
          conn.rpc args
          EventMachine::stop_event_loop
        end
        conn.errback do
          #EventMachine::stop_event_loop
          raise "errorback!"
        end
      end
    }
    if EM.reactor_running?
      rpcsetup.call
    else
      EM.run &rpcsetup
    end
  end

  def self.method_missing name, *args
    if ERBY::config.has_module? name.to_sym
      return ErlangModuleHelper.new name
    else
      super
    end
  end

  private
  def self.mod_and_fun calee
    data = calee.to_s.split ':'
    raise ArgumentError if data[0].blank? or data[1].blank? or data.length != 2
    [data[0].to_sym, data[1]]
  end
end