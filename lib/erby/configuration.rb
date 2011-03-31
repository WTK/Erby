module ERBY
  class Configuration
    attr_accessor :port_map, :modules

    def initialize
      @port_map = {}
      @modules = {}
    end

    # Returns port for given module
    def port_for mod
      raise TypeError unless mod.is_a? Symbol
      raise ConfigurationError unless @modules.has_key? mod
      map_port_for(mod) unless @port_map.has_key? mod
      @port_map[mod]
    end

    def modules= v
      @modules = v
    end

    def has_module? mod
      @modules.has_key? mod
    end

    def get_config_for mod
      raise ConfigurationError unless @modules.has_key? mod
      @modules[mod]
    end

    private
    # Connects to epmd to get port number that node
    # with desired module (mod) listens on for incoming connections
    def map_port_for mod
      c = @modules[mod]
      @port_map[mod] = Epmd::EpmdConnection.lookup_node c[:node], c[:server], c[:epmd_port]
    end
  end

  class ConfigurationError < StandardError
  end
  
  @config ||= Configuration.new

  def self.config
    @config
  end

  def self.configure
    yield @config
  end
end