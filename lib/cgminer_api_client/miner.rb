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
      return unless available?

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

    def available?(force_reload = false)
      @available = nil if force_reload

      @available ||= begin
        open_socket(@host, @port, @timeout).close
        true
      rescue StandardError
        false
      end
    end

    def method_missing(name, *args)
      query(name, *args)
    end

    def respond_to_missing?(name, include_private = false)
      return false if name.to_s.start_with?('to_', '_')

      super || true
    end

    private

    def perform_request(request)
      begin
        s = open_socket(@host, @port, @timeout)
      rescue StandardError
        raise "Connection to #{@host}:#{@port} failed"
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

      case sc
      when 'S'
        nil # success — no action
      when 'I'
        puts "Info from API [#{c}]: #{msg}"
      when 'W'
        puts "Warning from API [#{c}]: #{msg}"
      else
        raise "#{c}: #{msg}"
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
