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

    # Runs `method` against every miner in the pool in parallel and
    # returns a PoolResult — an Enumerable wrapper around a
    # MinerResult per miner, in pool order. Successes and failures
    # are both captured structurally; this method does NOT write
    # to stderr. Callers that want to display failures should
    # iterate the result (or use PoolResult#errors).
    def query(method, *params)
      threads = @miners.map do |miner|
        Thread.new do
          MinerResult.success(miner, miner.query(method, *params))
        rescue StandardError => e
          MinerResult.failure(miner, e)
        end
      end
      threads.each(&:join)
      PoolResult.new(threads.map(&:value))
    end

    # The Commands::ReadOnly convenience methods that unwrap
    # single-element cgminer responses with `query(:name)[0]` make
    # sense on a single Miner, but on a MinerPool they silently
    # returned only the first miner's hash — a pre-existing latent
    # bug masked by always calling .first on the result.
    #
    # Override them here to return a PoolResult where each
    # successful MinerResult carries the unwrapped hash instead of
    # the one-element array. Failures pass through unchanged.
    %i[summary coin config version].each do |cmd|
      define_method(cmd) do
        unwrap_first(query(cmd))
      end
    end

    def check(command)
      unwrap_first(query(:check, command))
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

    # Rebuild a PoolResult where each successful MinerResult's
    # value is replaced with value.first (i.e. the unwrapped
    # single-element response). Failures pass through unchanged.
    def unwrap_first(pool_result)
      PoolResult.new(pool_result.results.map do |r|
        r.ok? ? MinerResult.success(r.miner, r.value.first) : r
      end)
    end

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
