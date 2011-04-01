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
        :module_name => {:server => 'server.with.module', :node => 'node_with_module', :module => 'module_name', :cookie => 'ERLANGCOOKIEVALUE', :epmd_port => 4369},
        :dbapi => {:server => 'server1', :node => 'dbapi', :module => 'dbapi', :cookie => 'XPXPXPXPXPXPPXPXPXP', :epmd_port => 4369},
        :math => {:server => 'server2', :node => 'math', :module => 'math', :cookie => 'XPXPXPXPXPXPPXPXPXP', :epmd_port => 4369}
      }
    end

Usage
-----

Provided modules are configured as described above, you can call their functions using either commands:

    ERBY.module_name.function_name(arg1, arg2, argN)
    # => result
    ERBY.call('module_name:function_name', [args1, arg2, argN])
    # => result

Examples
--------

    ERBY.math.add(60, 4)
    # => 64
    ERBY.call('math:add', [60, 4])
    # => 64

TODO
----

Documentation and tests.