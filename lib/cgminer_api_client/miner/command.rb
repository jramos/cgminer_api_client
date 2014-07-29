module CgminerApiClient
  class Miner
    module Command
      def coin
        query(:coin)[:coin][0]
      end

      def config
        query(:config)[:config][0]
      end

      def devdetails
        query(:devdetails)[:devdetails]
      end

      def devs
        query(:devs)[:devs]
      end

      def pools
        query(:pools)[:pools]
      end

      def notify
        query(:notify)[:notify][0]
      end

      def stats
        query(:stats)[:stats]
      end

      def summary
        query(:summary)[:summary][0]
      end

      def usbstats
        query(:usbstats)[:usbstats]
      end

      def version
        query(:version)[:version][0]
      end
    end
  end
end