# frozen_string_literal: true

module CgminerApiClient
  # Base class for all errors raised by the gem. Catch this if you want
  # to handle every cgminer-specific failure together.
  class Error < StandardError; end

  # Raised when the gem cannot reach a miner: socket open failure, DNS
  # failure, connect timeout, or any other transport-level problem.
  # Distinct from ApiError so callers can tell "I never spoke to the
  # miner" apart from "the miner spoke to me and refused."
  class ConnectionError < Error; end

  # Raised specifically for connect-timeout failures, as a subclass
  # of ConnectionError. Lets callers distinguish "the miner took too
  # long to answer the SYN" from other connection-layer problems.
  class TimeoutError < ConnectionError; end

  # Raised when the miner returned a response whose STATUS field
  # indicates an error (cgminer status code 'E' or 'F'). The message
  # contains the cgminer code and message verbatim. Two structured
  # fields are also attached so callers can dispatch without parsing
  # English error strings:
  #
  #   #cgminer_code -- the integer Code from cgminer's STATUS hash
  #                    (e.g., 45 for access denied), or nil if the
  #                    error wasn't sourced from a cgminer response
  #                    (e.g., the gem's own access_denied? guard
  #                    raises before any wire interaction).
  #   #code         -- a symbolic Ruby tag derived from cgminer_code
  #                    via CGMINER_CODES, or :unknown if the integer
  #                    isn't in the map. Callers can also pass an
  #                    explicit code: kwarg when raising from a path
  #                    that doesn't carry a cgminer integer.
  #
  # cgminer's MSG enum names are stable but the integers occasionally
  # shift between firmware versions, so the integer is preserved
  # verbatim and the symbol is best-effort. Add a row to CGMINER_CODES
  # when you find a code worth dispatching on; the map is intentionally
  # conservative (only codes the test suite or production has actually
  # observed against real cgminer traffic).
  #
  # Backward compatibility: ApiError still accepts a single positional
  # message argument, so `raise ApiError, "msg"` keeps working. Existing
  # rescues that read .message see the same string they always did.
  class ApiError < Error
    CGMINER_CODES = {
      14 => :invalid_command,
      45 => :access_denied
    }.freeze

    attr_reader :cgminer_code, :code

    def initialize(message = nil, cgminer_code: nil, code: nil)
      super(message)
      @cgminer_code = cgminer_code
      @code = (code || CGMINER_CODES[cgminer_code] || :unknown).to_sym
    end
  end
end
