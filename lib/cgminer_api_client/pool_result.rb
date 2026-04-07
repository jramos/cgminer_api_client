# frozen_string_literal: true

module CgminerApiClient
  # An Enumerable wrapper around Array<MinerResult> returned from
  # every MinerPool query. Preserves miner order (position N in the
  # pool maps to position N in the result). Callers can either
  # iterate per-Result for full control, or use the high-level
  # helpers for common cases.
  #
  # Usage:
  #   result = pool.summary
  #   result.values          # [{mhs_av: ..., elapsed: ...}]  — successes only
  #   result.errors          # [<ConnectionError>, ...]       — failures only
  #   result.successful      # [<MinerResult>, ...]           — ok? Results
  #   result.failed          # [<MinerResult>, ...]           — !ok? Results
  #   result.all_successful? # true if every miner succeeded
  #   result.any_succeeded?  # true if at least one miner succeeded
  #   result.any_failed?     # true if any miner failed
  #   result[0]              # MinerResult at index 0
  #   result[miner]          # MinerResult for a specific Miner instance
  #   result["10.0.0.1:4028"] # MinerResult by "host:port" string
  #   result.each { |r| r.miner.host }  # iterates MinerResult instances
  class PoolResult
    include Enumerable

    attr_reader :results

    def initialize(results)
      @results = results.freeze
    end

    def each(&)
      @results.each(&)
    end

    def size
      @results.size
    end

    def empty?
      @results.empty?
    end

    def to_a
      @results.dup
    end

    def values
      @results.select(&:ok?).map(&:value)
    end

    def errors
      @results.reject(&:ok?).map(&:error)
    end

    def successful
      @results.select(&:ok?)
    end

    def failed
      @results.reject(&:ok?)
    end

    def all_successful?
      @results.all?(&:ok?)
    end

    def any_succeeded?
      @results.any?(&:ok?)
    end

    def any_failed?
      @results.any?(&:failed?)
    end

    # Lookup by integer index, Miner instance, or "host:port" string.
    def [](key)
      case key
      when Integer then @results[key]
      when String  then @results.find { |r| "#{r.miner.host}:#{r.miner.port}" == key }
      else              @results.find { |r| r.miner == key }
      end
    end

    def ==(other)
      other.is_a?(self.class) && @results == other.results
    end
    alias eql? ==

    def hash
      @results.hash
    end
  end
end
