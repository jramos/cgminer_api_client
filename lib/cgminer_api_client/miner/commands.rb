module CgminerApiClient
  class Miner
    module Commands
      module ReadOnly
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

      module Privileged
        module General
          def quit
            query(:quit) unless access_denied?
          end

          def restart
            query(:restart) unless access_denied?
          end
        end

        module Pool
          def addpool(url, user, pass)
            query(:addpool, url, user, pass) unless access_denied?
          end

          def disablepool(number)
            query(:disablepool, number) unless access_denied?
          end

          def enablepool(number)
            query(:enablepool, number) unless access_denied?
          end

          def poolpriority(*id_order)
            query(:poolpriority, *id_order) unless access_denied?
          end

          def poolquota(number, value)
            query(:poolquota, number, value) unless access_denied?
          end

          def removepool(number)
            query(:removepool, number) unless access_denied?
          end

          def switchpool
            query(:switchpool, number) unless access_denied?
          end
        end

        private

        def access_denied?
          if !privileged?
            raise 'access_denied'
          else
            return false
          end
        end

        include Miner::Commands::Privileged::General
        include Miner::Commands::Privileged::Pool
      end

      include Miner::Commands::ReadOnly
      include Miner::Commands::Privileged
    end
  end
end