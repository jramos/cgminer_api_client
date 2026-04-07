# frozen_string_literal: true

module CgminerApiClient
  class MinerPool
    include Miner::Commands

    attr_accessor :miners

    def initialize
      load_miners!
    end

    def reload_miners!
      @miners = nil
      load_miners!
    end

    def query(method, *params)
      threads = @miners.collect do |miner|
        Thread.new do
          miner.query(method, *params)
        rescue StandardError => e
          warn "[#{miner.host}:#{miner.port}] #{e.class}: #{e.message}"
          []
        end
      end
      threads.each(&:join)
      threads.collect(&:value)
    end

    def available_miners(force_reload = false)
      threads = @miners.collect do |miner|
        Thread.new do
          miner if miner.available?(force_reload)
        rescue StandardError
          nil
        end
      end
      threads.each(&:join)
      threads.collect(&:value).compact
    end

    def unavailable_miners(force_reload = false)
      @miners - available_miners(force_reload)
    end

    def method_missing(name, *)
      query(name, *)
    end

    # See Miner#respond_to_missing? for the rationale.
    def respond_to_missing?(name, _include_private = false)
      !name.to_s.start_with?('to_', '_')
    end

    private

    def load_miners!
      raise 'Please create config/miners.yml' unless File.exist?('config/miners.yml')

      miners_config = YAML.safe_load_file('config/miners.yml')
      @miners = miners_config.collect do |miner|
        CgminerApiClient::Miner.new(
          miner['host'],
          miner['port'],
          miner['timeout']
        )
      end
    end
  end
end
