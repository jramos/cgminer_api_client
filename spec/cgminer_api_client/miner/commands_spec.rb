require 'spec_helper'

describe CgminerApiClient::Miner::Commands do
  let(:host)     { '127.0.0.1' }
  let(:port)     { 4028 }
  let(:instance) { CgminerApiClient::Miner.new(host, port) }

  describe CgminerApiClient::Miner::Commands::ReadOnly do
    context '#asc' do
      it 'should require one argument' do
        expect {
          instance.asc
        }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
      end

      it 'should query the miner' do
        expect(instance).to receive(:query).with(:asc, 0).and_return('asc' => {})
        instance.asc(0)
      end
    end

    context '#asccount' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:asccount).and_return('asccount' => {})
        instance.asccount
      end
    end

    context '#check' do
      it 'should require one argument' do
        expect {
          instance.check
        }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
      end

      it 'should query the miner' do
        expect(instance).to receive(:check).with(:foo).and_return('foo' => [{}])
        instance.check(:foo)
      end
    end

    context '#coin' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:coin).and_return('coin' => [{}])
        instance.coin
      end
    end

    context '#config' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:config).and_return('config' => [{}])
        instance.config
      end
    end

    context '#devdetails' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:devdetails).and_return('devdetails' => [{}])
        instance.devdetails
      end
    end

    context '#devs' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:devs).and_return('devs' => [{}])
        instance.devs
      end
    end

    context '#pga' do
      it 'should require one argument' do
        expect {
          instance.pga
        }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
      end

      it 'should query the miner' do
        expect(instance).to receive(:query).with(:pga, 0).and_return('pga' => [{}])
        instance.pga(0)
      end
    end

    context '#pgacount' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:pgacount).and_return('pgacount' => [{}])
        instance.pgacount
      end
    end

    context '#pools' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:pgacount).and_return('pgacount' => [{}])
        instance.pgacount
      end
    end

    context '#privileged' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:privileged).and_return(nil)
        instance.privileged
      end

      context 'an exception' do
        before do
          expect(instance).to receive(:query).with(:privileged).and_raise('something')
        end

        it 'should return false' do
          expect(instance.privileged).to eq false
        end
      end

      context 'success' do
        before do
          expect(instance).to receive(:query).with(:privileged).and_return(nil)
        end

        it 'should return true' do
          expect(instance.privileged).to eq true
        end
      end
    end

    context '#notify' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:notify).and_return('notify' => [{}])
        instance.notify
      end
    end

    context '#stats' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:stats).and_return('stats' => [{}])
        instance.stats
      end
    end

    context '#summary' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:summary).and_return('summary' => [{}])
        instance.summary
      end
    end

    context '#usbstats' do
      it 'should query the miner' do
        expect(instance).to receive(:query).with(:usbstats).and_return('usbstats' => [{}])
        instance.usbstats
      end
    end

    context '#version' do
      it 'should query the miner' do
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

        it 'should raise an error' do
          expect {
            instance.send(:access_denied?)
          }.to raise_error('access_denied')
        end
      end

      context 'when privileged' do
        before do
          allow(instance).to receive(:privileged).and_return(true)
        end

        it 'should return false' do
          expect(instance.send(:access_denied?)).to eq false
        end
      end
    end

    describe CgminerApiClient::Miner::Commands::Privileged::Asc do
      context 'ascdisable' do
        it 'should require one argument' do
          expect {
            instance.ascdisable
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:ascdisable, :number)
          instance.ascdisable(:number)
        end
      end

      context 'ascenable' do
        it 'should require one argument' do
          expect {
            instance.ascenable
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:ascenable, :number)
          instance.ascenable(:number)
        end
      end

      context 'ascidentify' do
        it 'should require one argument' do
          expect {
            instance.ascidentify
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:ascidentify, :number)
          instance.ascidentify(:number)
        end
      end

      context 'ascset' do
        it 'should require 2-3 arguments' do
          expect {
            instance.ascset
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 2..3)')
        end

        it 'should query the miner with 2 arguments' do
          expect(instance).to receive(:query).with(:ascset, :number, :foo)
          instance.ascset(:number, :foo)
        end

        it 'should query the miner with 3 arguments' do
          expect(instance).to receive(:query).with(:ascset, :number, :foo, :bar)
          instance.ascset(:number, :foo, :bar)
        end
      end
    end
    
    describe CgminerApiClient::Miner::Commands::Privileged::General do
      before do
        allow(instance).to receive(:access_denied?).and_return(false)
      end

      context 'quit' do
        it 'should query the miner' do
          expect(instance).to receive(:query).with(:quit)
          instance.quit
        end
      end

      context 'restart' do
        it 'should query the miner' do
          expect(instance).to receive(:query).with(:restart)
          instance.restart
        end
      end
    end

    describe CgminerApiClient::Miner::Commands::Privileged::Pga do
      context 'pgadisable' do
        it 'should require one argument' do
          expect {
            instance.pgadisable
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:pgadisable, :number)
          instance.pgadisable(:number)
        end
      end

      context 'pgaenable' do
        it 'should require one argument' do
          expect {
            instance.pgaenable
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:pgaenable, :number)
          instance.pgaenable(:number)
        end
      end

      context 'pgaidentify' do
        it 'should require one argument' do
          expect {
            instance.pgaidentify
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:pgaidentify, :number)
          instance.pgaidentify(:number)
        end
      end

      context 'pgaset' do
        it 'should require 2-3 arguments' do
          expect {
            instance.pgaset
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 2..3)')
        end

        it 'should query the miner with 2 arguments' do
          expect(instance).to receive(:query).with(:pgaset, :number, :foo)
          instance.pgaset(:number, :foo)
        end

        it 'should query the miner with 3 arguments' do
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
        it 'should require three arguments' do
          expect {
            instance.addpool
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 3)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:addpool, :url, :user, :pass)
          instance.addpool(:url, :user, :pass)
        end
      end

      context 'disablepool' do
        it 'should require one argument' do
          expect {
            instance.disablepool
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:disablepool, :pool_number)
          instance.disablepool(:pool_number)
        end
      end

      context 'enablepool' do
        it 'should require one argument' do
          expect {
            instance.enablepool
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:enablepool, :pool_number)
          instance.enablepool(:pool_number)
        end
      end

      context 'poolpriority' do
        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:poolpriority, :pool_number_1, :pool_number_2, :pool_number_3)
          instance.poolpriority(:pool_number_1, :pool_number_2, :pool_number_3)
        end
      end

      context 'poolquota' do
        it 'should require two arguments' do
          expect {
            instance.poolquota
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 2)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:poolquota, :pool_number, :quota)
          instance.poolquota(:pool_number, :quota)
        end
      end

      context 'removepool' do
        it 'should require one argument' do
          expect {
            instance.removepool
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:removepool, :pool_number)
          instance.removepool(:pool_number)
        end
      end

      context 'switchpool' do
        it 'should require one argument' do
          expect {
            instance.switchpool
          }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
        end

        it 'should query the miner with arguments' do
          expect(instance).to receive(:query).with(:switchpool, :pool_number)
          instance.switchpool(:pool_number)
        end
      end
    end
  end
end
