Erby
=======

Erby is a Ruby-to-Erlang library for making fast rpc calls.
Depends on Eventmachine library.
Inspired by Bertrpc, pyInterface as well as rinterface because of its incomplete nature when it comes to handling erlang distribution protocol.


Installation
------------

    TODO


Configuration
-------------

    ERBY.configure do |config|
      config.modules = {
        :dbapi => {:server => 'server1', :node => 'dbapi', :module => 'dbapi', :cookie => 'XPXPXPXPXPXPPXPXPXP', :epmd_port => 4369},
        :math => {:server => 'server2', :node => 'math', :module => 'math', :cookie => 'XPXPXPXPXPXPPXPXPXP', :epmd_port => 4369}
      }
    end

Usage
-----

Provided you configured modules available. You can now call their functions using either commands:

    ERBY.module_name.function_name(arg1, arg2, argN)

Examples
--------

    ERBY.math.add(60, 4)
    # => 64
    ERBY.call('math:add', [60, 4])
    # => 64

TODO
----

    Documentation and tests.