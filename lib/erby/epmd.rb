module ERBY
  module Epmd
    def self.port_for mod
      ERBY.config.port_for mod
    end

    class EpmdConnection < EM::Connection
      include EM::Deferrable
      attr_accessor :nodename, :msg

      def initialize
        @msg = ERBY::Erlang::Encoder.new
      end

      def self.lookup_node nodename, epmd_server, epmd_port
        lookup = proc {
          conn = EM.connect epmd_server, epmd_port, self do |conn|
            conn.nodename = nodename
          end
          conn.callback do |port|
            return port
          end
          conn.errback do
            raise EpmdConnectionError
          end
        }
        if EM.reactor_running?
          lookup.call
        else
          EM.run &lookup
        end
      end

      def connection_completed
        send_lookup_port
      end

      def receive_data data
        d = ERBY::Erlang::Decoder.new data
        d.read_1 # read one to move inner pointer of decoder
        if d.read_1 == 0
          port = d.read_2
          succeed port
        else
          fail
        end
      end

      private
      def send_lookup_port
        @msg.int2 @nodename.length+1
        @msg.int1 122
        @msg.write @nodename
        send_message
      end

      def send_message
        send_data @msg
        @msg.reset
      end
    end

    class EpmdConnectionError < StandardError
    end
  end
end