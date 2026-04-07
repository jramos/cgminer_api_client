# frozen_string_literal: true

require 'cgminer_api_client/socket_with_timeout'
require 'cgminer_api_client/miner/commands'

module CgminerApiClient
  class Miner
    include SocketWithTimeout
    include Miner::Commands

    attr_accessor :host, :port, :timeout

    def initialize(host = nil, port = nil, timeout = nil)
      @host    = host    || CgminerApiClient.default_host
      @port    = port    || CgminerApiClient.default_port
      @timeout = timeout || CgminerApiClient.default_timeout
    end

    def query(method, *params)
      request = { command: method }

      unless params.empty?
        # cgminer uses comma to separate parameters, so any literal commas in
        # parameter values must be backslash-escaped, and any literal
        # backslashes must themselves be doubled. The block form of gsub is
        # used so the replacement string isn't interpreted (in gsub's
        # replacement-string syntax, '\\' means a single literal backslash,
        # which makes the obvious gsub('\\', '\\\\') a silent no-op).
        params = params.map { |p| p.to_s.gsub('\\') { '\\\\' }.gsub(',') { '\\,' } }
        request[:parameter] = params.join(',')
      end

      response = perform_request(request)
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

    def perform_request(request)
      begin
        s = open_socket(@host, @port, @timeout)
      rescue StandardError => e
        raise ConnectionError, "Connection to #{@host}:#{@port} failed: #{e.class}: #{e.message}"
      end

      s.write(request.to_json)
      response = s.read.strip.chars.map { |c| c.ord >= 32 ? c : format('\\u%04x', c.ord) }.join
      s.close

      response.gsub! '}{', '}, {'
      response.gsub! '[,{', '[ {'

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
      # E=Error, F=Fatal. Errors and Fatals raise ApiError so callers
      # can distinguish them from ConnectionError (transport-level
      # failures).
      case sc
      when 'S'
        # no-op: success needs no notification
      when 'I'
        puts "Info from API [#{c}]: #{msg}"
      when 'W'
        puts "Warning from API [#{c}]: #{msg}"
      else
        raise ApiError, "#{c}: #{msg}"
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
