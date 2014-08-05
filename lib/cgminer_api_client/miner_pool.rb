require 'thread'

module CgminerApiClient
  class MinerPool
    require 'yaml'

    attr_accessor :miners

    def initialize
      raise 'Please create config/miners.yml' unless File.exist?('config/miners.yml')
      load_miners!
    end

    def query(method, *params)
      threads = @miners.collect do |miner|
        Thread.new { miner.query(method, params) }
      end
      threads.each { |thr| thr.join }
      threads.collect(&:value).flatten
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