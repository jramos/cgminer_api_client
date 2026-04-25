# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::Miner::Commands do
  let(:host)     { '127.0.0.1' }
  let(:port)     { 4028 }
  let(:instance) { CgminerApiClient::Miner.new(host, port) }

  describe CgminerApiClient::Miner::Commands::ReadOnly do
    describe '#asc' do
      it 'requires one argument' do
        expect do
          instance.asc
        end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end

      it 'queries the miner' do
        expect(instance).to receive(:query).with(:asc, 0).and_return('asc' => {})
        instance.asc(0)
      end
    end

    describe '#asccount' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:asccount).and_return('asccount' => {})
        instance.asccount
      end
    end

    describe '#check' do
      it 'requires one argument' do
        expect do
          instance.check
        end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end

      it 'queries the miner' do
        expect(instance).to receive(:query).with(:check, :foo).and_return('foo' => [{}])
        instance.check(:foo)
      end
    end

    describe '#coin' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:coin).and_return('coin' => [{}])
        instance.coin
      end
    end

    describe '#config' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:config).and_return('config' => [{}])
        instance.config
      end
    end

    describe '#devdetails' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:devdetails).and_return('devdetails' => [{}])
        instance.devdetails
      end
    end

    describe '#devs' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:devs).and_return('devs' => [{}])
        instance.devs
      end
    end

    describe '#pga' do
      it 'requires one argument' do
        expect do
          instance.pga
        end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end

      it 'queries the miner' do
        expect(instance).to receive(:query).with(:pga, 0).and_return('pga' => [{}])
        instance.pga(0)
      end
    end

    describe '#pgacount' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:pgacount).and_return('pgacount' => [{}])
        instance.pgacount
      end
    end

    describe '#pools' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:pools).and_return('pools' => [{}])
        instance.pools
      end
    end

    describe '#privileged' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:privileged).and_return(nil)
        instance.privileged
      end

      context 'when the miner answers and rejects (ApiError)' do
        before do
          expect(instance).to receive(:query).with(:privileged)
                                             .and_raise(CgminerApiClient::ApiError, 'access denied')
        end

        it 'returns false' do
          expect(instance.privileged).to eq false
        end
      end

      context 'when the miner cannot be reached (ConnectionError)' do
        before do
          expect(instance).to receive(:query).with(:privileged)
                                             .and_raise(CgminerApiClient::ConnectionError, 'host unreachable')
        end

        it 'propagates the ConnectionError instead of mislabeling it as access-denied' do
          expect { instance.privileged }.to raise_error(CgminerApiClient::ConnectionError)
        end
      end

      context 'when query raises any other StandardError' do
        before do
          expect(instance).to receive(:query).with(:privileged).and_raise(StandardError, 'boom')
        end

        it 'propagates the error so bugs are not silently swallowed' do
          expect { instance.privileged }.to raise_error(StandardError, 'boom')
        end
      end

      context 'when the miner answers successfully' do
        before do
          expect(instance).to receive(:query).with(:privileged).and_return(nil)
        end

        it 'returns true' do
          expect(instance.privileged).to eq true
        end
      end
    end

    describe '#notify' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:notify).and_return('notify' => [{}])
        instance.notify
      end
    end

    describe '#stats' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:stats).and_return('stats' => [{}])
        instance.stats
      end
    end

    describe '#summary' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:summary).and_return('summary' => [{}])
        instance.summary
      end
    end

    describe '#usbstats' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:usbstats).and_return('usbstats' => [{}])
        instance.usbstats
      end
    end

    describe '#version' do
      it 'queries the miner' do
        expect(instance).to receive(:query).with(:version).and_return('version' => [{}])
        instance.version
      end
    end
  end

  describe CgminerApiClient::Miner::Commands::Privileged do
    context 'access_denied?' do
      context 'when not privileged' do
        before do
          allow(instance).to receive(:privileged).and_return(false)
        end

        it 'raises ApiError so it is caught by rescue CgminerApiClient::Error' do
          expect do
            instance.send(:access_denied?)
          end.to raise_error(CgminerApiClient::ApiError, 'access denied')
        end

        it 'attaches code: :access_denied so callers can dispatch without parsing the message' do
          # privileged is stubbed to return false here, so access_denied?
          # re-raises with the symbolic code only — cgminer_code stays
          # nil because there's no wire integer to inherit (the real
          # wire path inside privileged would have raised with code 45,
          # but privileged's rescue dropped it). Dispatch on e.code
          # works identically for both paths.
          expect { instance.send(:access_denied?) }
            .to raise_error(CgminerApiClient::ApiError) do |e|
              expect(e.code).to eq(:access_denied)
              expect(e.cgminer_code).to be_nil
            end
        end
      end

      context 'when privileged' do
        before do
          allow(instance).to receive(:privileged).and_return(true)
        end

        it 'returns false' do
          expect(instance.send(:access_denied?)).to eq false
        end
      end
    end

    describe CgminerApiClient::Miner::Commands::Privileged::Asc do
      before do
        allow(instance).to receive(:access_denied?).and_return(false)
      end

      context 'ascdisable' do
        it 'requires one argument' do
          expect do
            instance.ascdisable
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:ascdisable, :number)
          instance.ascdisable(:number)
        end
      end

      context 'ascenable' do
        it 'requires one argument' do
          expect do
            instance.ascenable
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:ascenable, :number)
          instance.ascenable(:number)
        end
      end

      context 'ascidentify' do
        it 'requires one argument' do
          expect do
            instance.ascidentify
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:ascidentify, :number)
          instance.ascidentify(:number)
        end
      end

      context 'ascset' do
        it 'requires 2-3 arguments' do
          expect do
            instance.ascset
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2..3)')
        end

        it 'queries the miner with 2 arguments' do
          expect(instance).to receive(:query).with(:ascset, :number, :foo)
          instance.ascset(:number, :foo)
        end

        it 'queries the miner with 3 arguments' do
          expect(instance).to receive(:query).with(:ascset, :number, :foo, :bar)
          instance.ascset(:number, :foo, :bar)
        end
      end
    end

    describe CgminerApiClient::Miner::Commands::Privileged::Pga do
      before do
        allow(instance).to receive(:access_denied?).and_return(false)
      end

      context 'pgadisable' do
        it 'requires one argument' do
          expect do
            instance.pgadisable
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:pgadisable, :number)
          instance.pgadisable(:number)
        end
      end

      context 'pgaenable' do
        it 'requires one argument' do
          expect do
            instance.pgaenable
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:pgaenable, :number)
          instance.pgaenable(:number)
        end
      end

      context 'pgaidentify' do
        it 'requires one argument' do
          expect do
            instance.pgaidentify
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:pgaidentify, :number)
          instance.pgaidentify(:number)
        end
      end

      context 'pgaset' do
        it 'requires 2-3 arguments' do
          expect do
            instance.pgaset
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2..3)')
        end

        it 'queries the miner with 2 arguments' do
          expect(instance).to receive(:query).with(:pgaset, :number, :foo)
          instance.pgaset(:number, :foo)
        end

        it 'queries the miner with 3 arguments' do
          expect(instance).to receive(:query).with(:pgaset, :number, :foo, :bar)
          instance.pgaset(:number, :foo, :bar)
        end
      end
    end

    describe CgminerApiClient::Miner::Commands::Privileged::Pool do
      before do
        allow(instance).to receive(:access_denied?).and_return(false)
      end

      context 'addpool' do
        it 'requires three arguments' do
          expect do
            instance.addpool
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 3)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:addpool, :url, :user, :pass)
          instance.addpool(:url, :user, :pass)
        end
      end

      context 'disablepool' do
        it 'requires one argument' do
          expect do
            instance.disablepool
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:disablepool, :pool_number)
          instance.disablepool(:pool_number)
        end
      end

      context 'enablepool' do
        it 'requires one argument' do
          expect do
            instance.enablepool
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:enablepool, :pool_number)
          instance.enablepool(:pool_number)
        end
      end

      context 'poolpriority' do
        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:poolpriority, :pool_number_1, :pool_number_2, :pool_number_3)
          instance.poolpriority(:pool_number_1, :pool_number_2, :pool_number_3)
        end
      end

      context 'poolquota' do
        it 'requires two arguments' do
          expect do
            instance.poolquota
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:poolquota, :pool_number, :quota)
          instance.poolquota(:pool_number, :quota)
        end
      end

      context 'removepool' do
        it 'requires one argument' do
          expect do
            instance.removepool
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:removepool, :pool_number)
          instance.removepool(:pool_number)
        end
      end

      context 'switchpool' do
        it 'requires one argument' do
          expect do
            instance.switchpool
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:switchpool, :pool_number)
          instance.switchpool(:pool_number)
        end
      end
    end

    describe CgminerApiClient::Miner::Commands::Privileged::System do
      before do
        allow(instance).to receive(:access_denied?).and_return(false)
      end

      context 'debug' do
        it 'queries the miner with defaults' do
          expect(instance).to receive(:query).with(:debug, 'D')
          instance.debug
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:debug, :setting)
          instance.debug(:setting)
        end
      end

      context 'failover_only' do
        it 'requires one argument' do
          expect do
            instance.failover_only
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:'failover-only', :value)
          instance.failover_only(:value)
        end
      end

      context 'hotplug' do
        it 'requires one argument' do
          expect do
            instance.hotplug
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:hotplug, :value)
          instance.hotplug(:value)
        end
      end

      context 'quit' do
        it 'queries the miner' do
          expect(instance).to receive(:query).with(:quit)
          instance.quit
        end
      end

      context 'restart' do
        it 'queries the miner' do
          expect(instance).to receive(:query).with(:restart)
          instance.restart
        end
      end

      context 'save' do
        context 'without filename' do
          it 'queries the miner' do
            expect(instance).to receive(:query).with(:save)
            instance.save
          end
        end

        context 'with filename' do
          it 'queries the miner with arguments' do
            expect(instance).to receive(:query).with(:save, :filename)
            instance.save(:filename)
          end
        end
      end

      context 'setconfig' do
        it 'requires two arguments' do
          expect do
            instance.setconfig
          end.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2)')
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:setconfig, :name, :value)
          instance.setconfig(:name, :value)
        end
      end

      context 'zero' do
        it 'queries the miner with defaults' do
          expect(instance).to receive(:query).with(:zero, 'All', false)
          instance.zero
        end

        it 'queries the miner with arguments' do
          expect(instance).to receive(:query).with(:zero, :which, :full_summary)
          instance.zero(:which, :full_summary)
        end
      end
    end
  end
end
