module CgminerApiClient
  class Miner
    module Command
      def asc(number)
        query(:asc, number)
      end

      def asccount
        query(:asccount)
      end

      def check(command)
        query(:check, command)[0]
      end

      def coin
        query(:coin)[0]
      end

      def config
        query(:config)[0]
      end

      def devdetails
        query(:devdetails)
      end

      def devs
        query(:devs)
      end

      def pga(number)
        query(:pga, number)
      end

      def pgacount
        query(:pgacount)
      end

      def pools
        query(:pools)
      end

      def privileged?
        check_privileged = check('privileged')
        check_privileged[:exists] == 'Y' && check_privileged[:access] == 'Y'
      end

      def notify
        query(:notify)
      end

      def stats
        query(:stats)
      end

      def summary
        query(:summary)[0]
      end

      def usbstats
        query(:usbstats)
      end

      def version
        query(:version)[0]
      end
    end
  end
end