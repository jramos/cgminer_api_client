module CgminerApiClient
  class MinerPool
    attr_accessor :miners

    def initialize
      raise 'Please create config/miners.yml' unless File.exist?('config/miners.yml')
      load_miners!
    end

    def available_miners
      threads = @miners.collect do |miner|
        Thread.new do
          begin
            miner if miner.available?
          rescue
            nil
          end
        end
      end
      threads.each { |thr| thr.join }
      threads.collect(&:value).compact
    end

    def query(method, *params)
      threads = @miners.collect do |miner|
        Thread.new do
          begin
            miner.query(method, *params)
          rescue => e
            $stderr.puts "#{e.class}: #{e}"
            []
          end
        end
      end
      threads.each { |thr| thr.join }
      threads.collect(&:value)
    end

    def method_missing(name, *args)
      query(name, *args)
    end

    def reload_miners!
      @miners = nil
      load_miners!
    end

    private
    
    def load_miners!
      miners_config = YAML.load_file('config/miners.yml')
      @miners = miners_config.collect{|miner|
        CgminerApiClient::Miner.new(miner['host'], (miner['port'] || 4028), (miner['timeout'] || 5))
      }
    end
  end
end