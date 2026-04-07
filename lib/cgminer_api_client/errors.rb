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
  class ApiError < Error; end
end
