require 'spec_helper'

describe CgminerApiClient::Miner::Commands do
  let(:host)     { '127.0.0.1' }
  let(:port)     { 4028 }
  let(:instance) { CgminerApiClient::Miner.new(host, port) }

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

  context '#privileged?' do
    it 'should use the check command' do
      expect(instance).to receive(:check).with('privileged').and_return({})
      instance.privileged?
    end
    
    context 'command does not exist' do
      before do
        expect(instance).to receive(:check).with('privileged').and_return({:exists => 'N'})
      end

      it 'should return false' do
        expect(instance.privileged?).to eq false
      end
    end
    
    context 'command exists' do
      context 'access is N' do
        before do
          expect(instance).to receive(:check).with('privileged').and_return({:exists => 'Y', :access => 'N'})
        end

        it 'should return false' do
          expect(instance.privileged?).to eq false
        end
      end
      
      context 'access is Y' do
        before do
          expect(instance).to receive(:check).with('privileged').and_return({:exists => 'Y', :access => 'Y'})
        end

        it 'should return true' do
          expect(instance.privileged?).to eq true
        end
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
