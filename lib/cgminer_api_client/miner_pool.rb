module CgminerApiClient
  class MinerPool
    require 'yaml'

    attr_accessor :miners

    def initialize
      raise 'Please create config/miners.yml' unless File.exist?('config/miners.yml')
      load_miners!
    end

    def query(method, *params)
      @miners.collect{|miner| miner.query(method, params) }
    end

    def method_missing(name, *args)
      query(name, *args)
    end

    private
    
    def load_miners!
      miners_config = YAML.load_file('config/miners.yml')
      @miners = miners_config.collect{|miner|
        CgminerApiClient::Miner.new(miner['host'], (miner['port'] || 4028))
      }
    end
  end
end