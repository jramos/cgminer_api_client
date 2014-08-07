require 'cgminer_api_client/miner/commands'

module CgminerApiClient
  class Miner
    include Miner::Commands

    attr_accessor :host, :port

    def initialize(host, port)
      @host, @port = host, port
    end

    def available?
      begin
        TCPSocket.open(@host, @port).close
        true
      rescue
        false
      end
    end

    def query(method, *params)
      request = {command: method}

      unless params.length == 0
        params = params.map { |p| p.to_s.gsub('\\', '\\\\').gsub(',', '\,') }
        request[:parameter] = params.join(',')
      end

      response = perform_request(request)
      data = sanitized(response)
      method.to_s.match('\+') ? data : data[method.to_sym]
    end

    def method_missing(name, *args)
      query(name, *args)
    end

    private

    def perform_request(request)
      begin
        s = TCPSocket.open(@host, @port)
      rescue
        raise "Connection to #{@host}:#{@port} failed"
      end

      s.write(request.to_json)
      data = s.read.strip.chars.map { |c| c.ord >= 32 ? c : "\\u#{'%04x' % c.ord}" }.join
      s.close

      data = JSON.parse(data)

      if request[:command].to_s.match('\+')
        data.each_pair do |command, response|
          check_status(response.first) if response.respond_to?(:first)
        end
      else
        check_status(data)
      end

      return data
    end

    def check_status(data)
      status =   data['STATUS'][0]
      sc     = status['STATUS']
      c      = status['Code']
      msg    = status['Msg']

      case sc
        when 'S'
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
        data.inject({}) { |n, (k, v)| n[k.to_s.downcase.gsub(' ', '_').to_sym] = sanitized(v); n }
      elsif data.is_a?(Array)
        data.map { |v| sanitized(v) }
      else
        data
      end
    end
  end
end