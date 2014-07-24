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

    def print_summary
      @total_ghs = 0

      @miners.each do |miner|
        if miner.available?
          summary = miner.summary
          devices = miner.devices

          @total_ghs += summary[:ghs_av]

          puts "#{miner.host} - #{summary[:ghs_av]} GH/s"

          devices.each do |device|
            puts "\t#{device[:status]}\t#{device[:device_elapsed] / 60} min\t#{device[:temperature]} C\t#{device[:'device_hardware%']}%"
          end
        end
      end

      puts "\nTotal GH/s: #{@total_ghs}"
    end
  end
end