module CgminerApiClient
  class Miner
    module Command
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

      def pools
        query(:pools)
      end

      def notify
        query(:notify)[0]
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