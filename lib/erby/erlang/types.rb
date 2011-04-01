module ERBY
  module Erlang
    module Types
      SMALL_INT = 97
      INT = 98

      SMALL_BIGNUM = 110
      LARGE_BIGNUM = 111

      FLOAT = 99
      NEW_FLOAT = 70

      ATOM = 100
      REF = 101           #old style reference
      NEW_REF = 114
      PORT = 102          #not supported accross node boundaries
      PID = 103

      SMALL_TUPLE = 104
      LARGE_TUPLE = 105

      NIL = 106
      STRING = 107
      LIST = 108
      BIN = 109

      FUN = 117
      NEW_FUN = 112

      VERSION = 131

      MAX_INT = (1 << 27) -1
      MIN_INT = -(1 << 27)
      MAX_ATOM = 255

      class Pid
        attr_reader :node, :node_id, :serial, :creation
        def initialize(node,nid=5,serial=5,created=5)
          @node = node.to_sym
          @node_id = nid
          @serial = serial
          @creation = created
        end
      end

      class Tuple < Array
        def inspect
          "t#{super}"
        end
      end
    end
  end
end