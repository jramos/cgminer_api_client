module CgminerApiClient
  class Miner
    module Command
      def coin
        query(:coin)
      end

      def config
        query(:config)
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
        query(:notify)
      end

      def stats
        query(:stats)
      end

      def summary
        query(:summary)
      end

      def usbstats
        query(:usbstats)
      end

      def version
        query(:version)
      end
    end
  end
end