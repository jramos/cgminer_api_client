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
  # contains the cgminer code and message verbatim.
  #
  # Carries two structured fields for dispatch: callers `case e.code`
  # instead of parsing English messages. The integer (#cgminer_code)
  # is preserved verbatim from cgminer; the symbol (#code) is
  # best-effort — cgminer's MSG enum names are stable but the
  # integers occasionally shift between firmware versions, so add a
  # row to CGMINER_CODES when you find a wire-observed integer worth
  # dispatching on.
  #
  # Prefer #code for dispatch over #cgminer_code: paths that raise
  # without a wire integer (the access_denied? local guard's call
  # to #privileged hits the wire, but the rescue inside #privileged
  # drops the integer) leave #cgminer_code nil while still setting
  # #code consistently.
  #
  # Backward compatibility: `raise ApiError, "msg"` keeps working
  # and #message is unchanged at every emission site.
  class ApiError < Error
    CGMINER_CODES = {
      14 => :invalid_command,
      45 => :access_denied
    }.freeze

    attr_reader :cgminer_code, :code

    # Factory used at the wire-side emission point in Miner#check_status.
    # Picks AccessDeniedError when the cgminer integer maps to
    # :access_denied so callers can `rescue AccessDeniedError` for
    # the most commonly dispatched-on case; falls back to ApiError
    # for everything else. Wire boundary stays best-effort: a
    # non-numeric Code coerces to nil and the symbolic tag becomes
    # :unknown rather than raising mid-poll.
    def self.for_status(status_code, message)
      cgminer_code = Integer(status_code, exception: false)
      klass = CGMINER_CODES[cgminer_code] == :access_denied ? AccessDeniedError : ApiError
      klass.new("#{status_code}: #{message}", cgminer_code: cgminer_code)
    end

    def initialize(message = nil, cgminer_code: nil, code: nil)
      # Fail loud at the library boundary on bad input. Without this guard,
      # cgminer_code: "45" or 45.0 silently produces code: :unknown
      # because CGMINER_CODES uses integer keys — every dispatch site
      # would break with no signal. Wire-side callers that want best-effort
      # coercion should pass Integer(c, exception: false) themselves.
      unless cgminer_code.nil? || cgminer_code.is_a?(Integer)
        raise ArgumentError,
              "cgminer_code must be Integer or nil, got #{cgminer_code.class}: #{cgminer_code.inspect}"
      end

      super(message)
      @cgminer_code = cgminer_code
      @code = (code || CGMINER_CODES[cgminer_code] || :unknown).to_sym
    end
  end

  # Specific subclass for cgminer's "access denied" response (STATUS=E
  # Code 45) and the gem's own #access_denied? local guard. Inherits
  # from ApiError so existing `rescue ApiError` clauses still catch
  # it; callers wanting finer dispatch use `rescue AccessDeniedError`
  # instead of `case e.code; when :access_denied`. Constructor pins
  # code: :access_denied so the symbolic tag is consistent regardless
  # of which call site raised.
  class AccessDeniedError < ApiError
    def initialize(message = nil, cgminer_code: nil)
      super(message, cgminer_code: cgminer_code, code: :access_denied)
    end
  end
end
