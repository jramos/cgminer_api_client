# frozen_string_literal: true

require 'cgminer_api_client/socket_with_timeout'
require 'cgminer_api_client/miner/commands'

module CgminerApiClient
  class Miner
    include SocketWithTimeout
    include Miner::Commands

    attr_accessor :host, :port, :timeout

    # Positional parameters at these indices carry user-controlled values
    # (pool passwords, setconfig values, ascset/pgaset option values)
    # that should not appear verbatim in wire-logs. The wire request is
    # never modified; only the copy passed to the on_wire callback is
    # redacted. If a new privileged command is added that accepts a
    # secret positional arg, register its index here.
    REDACTED_PARAM_INDEX = {
      addpool: 2,
      setconfig: 1,
      ascset: 2,
      pgaset: 2
    }.freeze

    def initialize(host = nil, port = nil, timeout = nil, on_wire: nil)
      @host    = host    || CgminerApiClient.default_host
      @port    = port    || CgminerApiClient.default_port
      @timeout = timeout || CgminerApiClient.default_timeout
      @on_wire = on_wire
    end

    def query(method, *params)
      request, loggable_request = build_requests(method, params)
      response = perform_request(request, loggable_request: loggable_request)
      data = sanitized(response)
      method.to_s.match?('\+') ? data : data[method.to_sym]
    end

    # Reachability probe. Opens a fresh socket every call — no
    # caching. Returns true on a successful connect, false on
    # transport-level failure (DNS, refused, unreachable, timeout).
    # Bugs like ArgumentError or NoMethodError propagate instead
    # of being silently swallowed.
    def available?
      open_socket(@host, @port, @timeout).close
      true
    rescue SocketError, SystemCallError, CgminerApiClient::TimeoutError
      false
    end

    def method_missing(name, *)
      query(name, *)
    end

    # method_missing forwards everything to query as a cgminer command,
    # so respond to anything except names that look like Ruby internals
    # or implicit conversion probes (to_ary, to_str, to_int, to_hash, ...).
    def respond_to_missing?(name, _include_private = false)
      !name.to_s.start_with?('to_', '_')
    end

    private

    def build_requests(method, params)
      return [{ command: method }, { command: method }] if params.empty?

      escaped          = params.map { |p| escape_param(p) }
      loggable_escaped = redact_params(method, params).map { |p| escape_param(p) }

      [
        { command: method, parameter: escaped.join(',') },
        { command: method, parameter: loggable_escaped.join(',') }
      ]
    end

    # cgminer uses comma to separate parameters, so any literal commas in
    # parameter values must be backslash-escaped, and any literal
    # backslashes must themselves be doubled. The block form of gsub is
    # used so the replacement string isn't interpreted (in gsub's
    # replacement-string syntax, '\\' means a single literal backslash,
    # which makes the obvious gsub('\\', '\\\\') a silent no-op).
    def escape_param(param)
      param.to_s.gsub('\\') { '\\\\' }.gsub(',') { '\\,' }
    end

    def redact_params(method, params)
      idx = REDACTED_PARAM_INDEX[method.to_sym]
      return params unless idx && params[idx]

      redacted = params.dup
      redacted[idx] = '[REDACTED]'
      redacted
    end

    # on_wire is best-effort telemetry — a callback that raises must
    # not break the real query path or leak the connection. Operators
    # who suspect their callback is broken can remove -v to isolate.
    def safe_on_wire(direction, payload)
      return unless @on_wire

      @on_wire.call(direction, @host, @port, payload)
    rescue StandardError
      nil
    end

    def perform_request(request, loggable_request: request)
      begin
        s = open_socket(@host, @port, @timeout)
      rescue StandardError => e
        raise ConnectionError, "Connection to #{@host}:#{@port} failed: #{e.class}: #{e.message}"
      end

      safe_on_wire(:request, loggable_request.to_json)
      s.write(request.to_json)
      response = s.read.strip.chars.map { |c| c.ord >= 32 ? c : format('\\u%04x', c.ord) }.join
      s.close
      safe_on_wire(:response, response)

      # Legacy defensive repair for malformed multi-object responses. We
      # haven't reproduced a case where this actually fires on modern
      # cgminer; see spec/support/cgminer_fixtures.rb for commentary.
      # Keep in place until we can confirm it isn't needed on real traffic.
      # If the repair ever fires, emit an additional :response_repaired
      # callback so a broken-looking JSON log isn't mysterious.
      repaired = response.gsub('}{', '}, {').gsub('[,{', '[ {')
      if repaired != response
        safe_on_wire(:response_repaired, repaired)
        response = repaired
      end

      data = JSON.parse(response)

      if request[:command].to_s.match?('\+')
        data.each_pair do |_command, response|
          check_status(response.first) if response.respond_to?(:first)
        end
      else
        check_status(data)
      end

      data
    end

    def check_status(data)
      status = data['STATUS'][0]
      sc     = status['STATUS']
      c      = status['Code']
      msg    = status['Msg']

      # cgminer STATUS codes: S=Success (silent), I=Info, W=Warning,
      # E=Error, F=Fatal. Errors and Fatals raise via ApiError.for_status
      # which picks AccessDeniedError for Code 45 (so callers can
      # `rescue AccessDeniedError`) and falls back to ApiError otherwise.
      # The wire boundary stays best-effort — non-numeric Codes coerce
      # to nil and the symbolic tag becomes :unknown rather than
      # raising mid-poll.
      case sc
      when 'S'
        # no-op: success needs no notification
      when 'I'
        puts "Info from API [#{c}]: #{msg}"
      when 'W'
        puts "Warning from API [#{c}]: #{msg}"
      else
        raise ApiError.for_status(c, msg)
      end
    end

    def sanitized(data)
      if data.is_a?(Hash)
        data.each_with_object({}) do |(k, v), n|
          n[k.to_s.downcase.tr(' ', '_').to_sym] = sanitized(v)
        end
      elsif data.is_a?(Array)
        data.map { |v| sanitized(v) }
      else
        data
      end
    end
  end
end
