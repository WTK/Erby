module ERBY
  module Erlang
    class Encoder
      include Erlang::Types

      attr_accessor :out

      def initialize(out='')
        @out = StringIO.new(out)
      end

      def self.encode(data)
        io = StringIO.new
        self.new(io).write_any(data)
        io.string
      end

      def write_any obj
        write_1 Erlang::Types::VERSION
        write_any_raw obj
      end

      def write_any_raw obj
        case obj
          when Symbol then write_symbol(obj)
          when Fixnum, Bignum then write_fixnum(obj)
          when Float then write_float(obj)
          when Tuple then write_tuple(obj)
          when Array then write_list(obj)
          when String then write_binary(obj)
          when Pid then write_pid(obj)
          else
            fail(obj)
        end
      end

      def write v
        case v
          when String then write_string v
          when Symbol then write_symbol v
        end
      end

      def write_1(byte)
        out.write([byte].pack("C"))
      end
      alias :int1 :write_1

      def write_2(short)
        out.write([short].pack("n"))
      end
      alias :int2 :write_2

      def write_4(long)
        out.write([long].pack("N"))
      end
      alias :int4 :write_4

      def write_string(string)
        out.write(string)
      end
      alias :string :write_string

      def write_pid(pid)
        write_1 PID
        write_symbol pid.node
        write_4 (pid.node_id & 0x7fff)
        write_4 (pid.serial & 0x1fff)
        write_1 (pid.creation & 0x3)
      end

      def write_boolean(bool)
        write_symbol(bool.to_s.to_sym)
      end

      def write_symbol(sym)
        fail(sym) unless sym.is_a?(Symbol)
        data = sym.to_s
        write_1 ATOM
        write_2 data.length
        write_string data
      end

      def write_fixnum(num)
        if num >= 0 && num < 256
          write_1 SMALL_INT
          write_1 num
        elsif num <= MAX_INT && num >= MIN_INT
          write_1 INT
          write_4 num
        else
          write_bignum num
        end
      end

      def write_float(float)
        write_1 FLOAT
        write_string format("%15.15e", float).ljust(31, "\000")
      end

      def write_bignum(num)
        n = (num.to_s(2).size / 8.0).ceil
        if n < 256
          write_1 SMALL_BIGNUM
          write_1 n
          write_bignum_guts(num)
        else
          write_1 LARGE_BIGNUM
          write_4 n
          write_bignum_guts(num)
        end
      end

      def write_bignum_guts(num)
        write_1 (num >= 0 ? 0 : 1)
        num = num.abs
        while num != 0
          rem = num % 256
          write_1 rem
          num = num >> 8
        end
      end

      def write_tuple(data)
        fail(data) unless data.is_a? Array

        if data.length < 256
          write_1 SMALL_TUPLE
          write_1 data.length
        else
          write_1 LARGE_TUPLE
          write_4 data.length
        end

        data.each { |e| write_any_raw e }
      end

      def write_list(data)
        fail(data) unless data.is_a? Array
        write_1 NIL and return if data.empty?
        write_1 LIST
        write_4 data.length
        data.each{|e| write_any_raw e }
        write_1 NIL
      end

      def write_binary(data)
        write_1 BIN
        write_4 data.length
        write_string data
      end

      def reset
        @out = StringIO.new('', 'w')
      end

      def to_s
        @out.string
      end

      def length
        @out.string.length
      end

      private

      def fail(obj)
        raise "Cannot encode to erlang external format: #{obj.inspect}"
      end

#      attr_accessor :out
#
#      def initialize
#        @out = StringIO.new('', 'w')
#      end
#
#      def write v
#        case v
#          when String then write_string v
#          when Symbol then write_symbol v
#        end
#      end
#
#      def write_1 v
#        @out.write([v].pack("C"))
#      end
#      alias :int1 :write_1
#
#      def write_2 v
#        @out.write [v].pack('n')
#      end
#      alias :int2 :write_2
#
#      def write_4 v
#        @out.write [v].pack('N')
#      end
#      alias :int4 :write_4
#
#      def write_string v
#        @out.write v
#      end
#      alias :string :write_string
#
#      def write_symbol v
#        data = v.to_s
#        write_1 ATOM
#        write_2 data.length
#        write_string data
#      end
    end
  end
end