module CgminerApiClient
  class Pool
    require 'yaml'

    attr_accessor :miners

    def initialize
      raise 'Please create config/miners.yml' unless File.exist?('config/miners.yml')

      miners_config = YAML.load_file('config/miners.yml')
      @miners = miners_config.collect{|miner|
        CgminerApiClient::Remote.new(miner['host'], (miner['port'] || 4028))
      }
    end

    def query(method, *params)
      @miners.collect{|miner| miner.query(method, params) }
    end

    def method_missing(name, *args)
      query(name, *args)
    end
  end
end