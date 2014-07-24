module CgminerApiClient
  class Pool
    require 'yaml'

    attr_accessor :miners

    def initialize
      raise 'Please create config/miners.yml' unless File.exist?('config/miners.yml')

      miners_config = YAML.load_file('config/miners.yml')
      @miners = miners_config.collect{|miner|
        CgminerApiClient::Remote.new(miner['host'], (miner['port'] || 4028))
      }
    end

    def query(method, *params)
      @miners.collect{|miner| miner.query(method, params) }
    end

    def method_missing(name, *args)
      query(name, *args)
    end

    def print_summary
      @total_ghs = 0

      @miners.each do |miner|
        if miner.available?
          summary = miner.summary[:summary][0]
          devices = miner.devs[:devs]

          @total_ghs += summary[:ghs_av]

          puts "#{miner.host}:#{miner.port}"
          puts "\tGH/s\t#{summary[:ghs_av]}"
          puts "\tDevices\t#{devices.count}"

          devices.each do |device|
            puts "\t\tName\t#{device[:name]}"
            puts "\t\tStatus\t#{device[:status]}"
            puts "\t\tElapsed\t#{device[:device_elapsed] / 60} min"
            puts "\t\tTemp\t#{device[:temperature]} C"
            puts "\t\tErr\t#{device[:'device_hardware%']}%\n\n"
          end
        end
      end

      puts "\nTotal GH/s: #{@total_ghs.round(1)} (#{(@total_ghs / @miners.count).round(1)} avg/miner)"
    end
  end
end