require "eventmachine"
require "digest/md5"
require 'socket'
require 'stringio'

require 'erby/types'
require 'erby/encoder'
require 'erby/decoder'
require 'erby/epmd'
require 'erby/configuration'
require 'erby/node_connection'

module ERBY
  def self.version
    #File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION])).chomp
    config = YAML.load( File.join(File.dirname(__FILE__), *%w[.. VERSION.yml]) )
    "#{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  rescue
    'unknown'
  end

  VERSION = self.version
end