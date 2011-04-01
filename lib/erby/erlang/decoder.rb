module ERBY
  module Erlang
    class Decoder
      include Erlang::Types
      attr_accessor :in

      def self.decode(string)
        new(string).read_any
      end

      def initialize(ins)
        @in = StringIO.new(ins)
        @peeked = ""
      end

      def read_any
        raise "Bad version" unless read_1 == Erlang::Types::VERSION
        read_any_raw
      end

      def read_any_raw
        case peek_1
          when ATOM then read_atom
          when SMALL_INT then read_small_int
          when INT then read_int
          when SMALL_BIGNUM then read_small_bignum
          when LARGE_BIGNUM then read_large_bignum
          when FLOAT then read_float
          when SMALL_TUPLE then read_small_tuple
          when LARGE_TUPLE then read_large_tuple
          when NIL then read_nil
          when STRING then read_erl_string
          when LIST then read_list
          when BIN then read_bin
          when PID then read_pid
        else
          raise "Unknown term tag: #{peek_1}"
        end
      end

      def read(length)
        if length < @peeked.length
          result = @peeked[0...length]
          @peeked = @peeked[length..-1]
          length = 0
        else
          result = @peeked
          @peeked = ''
          length -= result.length
        end

        if length > 0
          result << @in.read(length)
        end
        result
      end

      def peek(length)
        if length <= @peeked.length
          @peeked[0...length]
        else
          read_bytes = @in.read(length - @peeked.length)
          @peeked << read_bytes if read_bytes
          @peeked
        end
      end

      def peek_1
        peek(1).unpack("C").first
      end

      def peek_2
        peek(2).unpack("n").first
      end

      def read_1
        read(1).unpack("C").first
      end
      alias :read_int1 :read_1

      def read_2
        read(2).unpack("n").first
      end
      alias :read_int2 :read_2

      def read_4
        read(4).unpack("N").first
      end
      alias :read_int4 :read_4

      def read_string(length)
        read(length)
      end

      def read_atom
        raise "Invalid Type, not an atom" unless read_1 == ATOM
        length = read_2
        a = read_string(length)
        case a
          when ""
            Marshal.load("\004\b:\005") # Workaround for inability to do ''.to_sym
          else
            a.to_sym
        end
      end

      def read_small_int
        raise "Invalid Type, not a small int" unless read_1 == SMALL_INT
        read_1
      end

      def read_int
        raise "Invalid Type, not an int" unless read_1 == INT
        value = read_4
        negative = (value >> 31)[0] == 1
        value = (value - (1 << 32)) if negative
        value = Integer(value)
      end

      def read_small_bignum
        raise "Invalid Type, not a small bignum" unless read_1 == SMALL_BIGNUM
        size = read_1
        sign = read_1
        bytes = read_string(size).unpack("C" * size)
        added = bytes.zip((0..bytes.length).to_a).inject(0) do |result, byte_index|
          byte, index = *byte_index
          value = (byte * (256 ** index))
          sign != 0 ? (result - value) : (result + value)
        end
        Bignum(added)
      end

      def read_large_bignum
        raise "Invalid Type, not a large bignum" unless read_1 == LARGE_BIGNUM
        size = read_4
        sign = read_1
        bytes = read_string(size).unpack("C" * size)
        added = bytes.zip((0..bytes.length).to_a).inject(0) do |result, byte_index|
          byte, index = *byte_index
          value = (byte * (256 ** index))
          sign != 0 ? (result - value) : (result + value)
        end
        Bignum(added)
      end

      def read_float
        raise "Invalid Type, not a float" unless read_1 == FLOAT
        string_value = read_string(31)
        result = string_value.to_f
      end

      def read_small_tuple
        raise "Invalid Type, not a small tuple" unless read_1 == SMALL_TUPLE
        read_tuple(read_1)
      end

      def read_large_tuple
        raise "Invalid Type, not a small tuple" unless read_1 == LARGE_TUPLE
        read_tuple(read_4)
      end

      def read_tuple(arity)
        if arity > 0
          tag = read_any_raw
          if tag == :bert
            read_complex_type(arity)
          else
            tuple = Tuple.new(arity)
            tuple[0] = tag
            (arity - 1).times { |i| tuple[i + 1] = read_any_raw }
            tuple
          end
        else
          Tuple.new
        end
      end

      def read_complex_type(arity)
        case read_any_raw
          when :nil
            nil
          when :true
            true
          when :false
            false
          when :time
            Time.at(read_any_raw * 1_000_000 + read_any_raw, read_any_raw)
          when :regex
            source = read_any_raw
            opts = read_any_raw
            options = 0
            options |= Regexp::EXTENDED if opts.include?(:extended)
            options |= Regexp::IGNORECASE if opts.include?(:caseless)
            options |= Regexp::MULTILINE if opts.include?(:multiline)
            Regexp.new(source, options)
          when :dict
            read_dict
          else
            nil
        end
      end

      def read_dict
        type = read_1
        raise "Invalid dict spec, not an erlang list" unless [LIST, NIL].include?(type)
        if type == LIST
          length = read_4
        else
          length = 0
        end
        hash = {}
        length.times do |i|
          pair = read_any_raw
          hash[pair[0]] = pair[1]
        end
        read_1 if type == LIST
        hash
      end

      def read_pid
        fail "Invalid Type, not a pid" unless read_1 == PID
        node = read_atom
        id = read_4
        serial = read_4
        creation = read_1
        Pid.new(node, id, serial, creation)
      end

      def read_nil
        raise "Invalid Type, not a nil list" unless read_1 == NIL
        []
      end

      def read_erl_string
        raise "Invalid Type, not an erlang string" unless read_1 == STRING
        length = read_2
        read_string(length).unpack('C' * length)
      end

      def read_list
        raise "Invalid Type, not an erlang list" unless read_1 == LIST
        length = read_4
        list = (0...length).map { |i| read_any_raw }
        read_1
        list
      end

      def read_bin
        Raise "Invalid Type, not an erlang binary" unless read_1 == BIN
        length = read_4
        read_string(length)
      end
    end
  end
end