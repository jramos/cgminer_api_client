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

        def privileged
          begin
            query(:privileged)
            true
          rescue
            false
          end
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
        module Asc
          def ascdisable(number)
            query(:ascdisable, number) unless access_denied?
          end

          def ascenable(number)
            query(:ascenable, number) unless access_denied?
          end

          def ascidentify(number)
            query(:ascidentify, number) unless access_denied?
          end

          def ascset(number, option, value = nil)
            unless access_denied?
              value ? query(:ascset, number, option, value) : query(:ascset, number, option)
            end
          end
        end

        module Pga
          def pgadisable(number)
            query(:pgadisable, number) unless access_denied?
          end

          def pgaenable(number)
            query(:pgaenable, number) unless access_denied?
          end

          def pgaidentify(number)
            query(:pgaidentify, number) unless access_denied?
          end

          def pgaset(number, option, value = nil)
            unless access_denied?
              value ? query(:pgaset, number, option, value) : query(:pgaset, number, option)
            end
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

          def switchpool(number)
            query(:switchpool, number) unless access_denied?
          end
        end

        module System
          def debug(setting = 'D')
            query(:debug, setting) unless access_denied?
          end

          def failover_only(value)
            query(:'failover-only', value) unless access_denied?
          end

          def hotplug(seconds)
            query(:hotplug, seconds) unless access_denied?
          end

          def quit
            query(:quit) unless access_denied?
          end

          def restart
            query(:restart) unless access_denied?
          end

          def save(filename = nil)
            unless access_denied?
              filename ? query(:save, filename) : query(:save)
            end
          end

          def setconfig(name, value)
            query(:setconfig, name, value) unless access_denied?
          end

          def zero(which = 'All', full_summary = false)
            query(:zero, which, full_summary) unless access_denied?
          end
        end

        private

        def access_denied?
          if !privileged
            raise 'access_denied'
          else
            return false
          end
        end

        include Miner::Commands::Privileged::Asc
        include Miner::Commands::Privileged::Pga
        include Miner::Commands::Privileged::Pool
        include Miner::Commands::Privileged::System
      end

      include Miner::Commands::ReadOnly
      include Miner::Commands::Privileged
    end
  end
end