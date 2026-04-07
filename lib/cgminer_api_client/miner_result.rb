# frozen_string_literal: true

module CgminerApiClient
  # A single per-miner outcome from a MinerPool query. Either a
  # successful response (error is nil, value holds the parsed data)
  # or a failure (value is nil, error holds the exception).
  #
  # Immutable value object backed by Data.define, which gives us
  # ==, hash, eql?, inspect, to_h, and deconstruct_keys for pattern
  # matching for free.
  #
  # Usage:
  #   result = pool.summary.first
  #   if result.ok?
  #     puts result.value[:mhs_av]
  #   else
  #     warn "#{result.miner.host}: #{result.error.message}"
  #   end
  #
  # Or with pattern matching:
  #   case result
  #   in { ok?: true, value: }  then use(value)
  #   in { ok?: false, error: } then log(error)
  #   end
  MinerResult = Data.define(:miner, :value, :error) do
    def self.success(miner, value)
      new(miner: miner, value: value, error: nil)
    end

    def self.failure(miner, error)
      new(miner: miner, value: nil, error: error)
    end

    def ok?
      error.nil?
    end

    def failed?
      !ok?
    end

    # Re-raise the captured error, or return the value if successful.
    # Equivalent to `result.ok? ? result.value : raise(result.error)`
    # but shorter at call sites.
    def raise!
      raise error if failed?

      value
    end
  end
end
