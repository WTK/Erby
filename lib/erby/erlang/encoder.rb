module ERBY
  module Erlang
    class Encoder
      include Erlang::Types

      attr_accessor :out

      def initialize
        @out = StringIO.new('', 'w')
      end

      def write v
        case v
          when String then write_string v
          when Symbol then write_symbol v
        end
      end

      def write_1 v
        @out.write([v].pack("C"))
      end
      alias :int1 :write_1

      def write_2 v
        @out.write [v].pack('n')
      end
      alias :int2 :write_2

      def write_4 v
        @out.write [v].pack('N')
      end
      alias :int4 :write_4

      def write_string v
        @out.write v
      end
      alias :string :write_string

      def write_symbol v
        data = v.to_s
        write_1 ATOM
        write_2 data.length
        write_string data
      end

      def reset
        @out = StringIO.new('', 'w')
      end

      def to_s
        @out.string
      end
    end
  end
end