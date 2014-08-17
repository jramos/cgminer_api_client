require 'spec_helper'

describe CgminerApiClient::MinerPool do
  let(:mock_miner)           { instance_double('CgminerApiClient::Miner') }
  let(:host)                 { '127.0.0.1' }
  let(:port)                 { 1234 }
  let(:timeout)              { 10 }
  let(:mock_miner_from_yaml) { double('miner_from_yaml', :[] => {'host' => host, 'port' => port, 'timeout' => timeout} ) }
  let(:instance)             { CgminerApiClient::MinerPool.new }

  before do
    allow(CgminerApiClient::Miner).to receive(:new).and_return(mock_miner)
  end

  context 'attributes' do
    context '@miners' do
      before do
        allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
        allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      end

      it 'should allow setting and getting' do
        instance.miners = :foo
        expect(instance.miners).to eq :foo
      end
    end
  end

  context '#initialize' do
    context 'no configuration file' do
      before do
        expect(File).to receive(:exist?).with('config/miners.yml').and_return(false)
      end

      it 'should raise an error' do
        expect{ 
          instance 
        }.to raise_error(RuntimeError)
      end
    end

    context 'with configuration file' do
      before do
        expect(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      end

      it 'should not raise an error' do
        allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)

        expect {
          instance
        }.to_not raise_error()
      end

      it 'should load the miners' do
        expect_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!)
        instance
      end
    end
  end

  context '#available_miners' do
    it 'should not include unavailable miners'
    it 'should include available miners'
  end

  context '#query' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      allow(instance).to receive(:load_miners!).and_return(true)
      instance.instance_variable_set(:@miners, [mock_miner])
    end

    it 'should run provided query on each miner' do
      expect(mock_miner).to receive(:query).with(:foo)
      instance.query(:foo)
    end

    it 'should pass parameters' do
      expect(mock_miner).to receive(:query).with(:foo, *[:parameters])
      instance.query(:foo, :parameters)
    end

    it 'should return an array' do
      allow(mock_miner).to receive(:query).with(:foo)
      expect(instance.query(:foo)).to be_kind_of(Array)
    end
  end

  context '#method_missing' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      allow(instance).to receive(:query).and_return(true)
    end

    it 'should query each miner with the method name' do
      expect(instance).to receive(:query).with(:foo).and_return(true)
      instance.method_missing(:foo)
    end

    it 'should pass arguments' do
      expect(instance).to receive(:query).with(:foo, [:arguments])
      instance.method_missing(:foo, [:arguments])
    end
  end

  context '#reload_miners!' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
    end

    it 'should call load_miners!' do
      expect(instance).to receive(:load_miners!)
      instance.reload_miners!
    end
  end

  context 'private methods' do
    context '#load_miners!' do
      before do
        allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      end

      it 'should parse the configuration file' do
        expect(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml]).at_least(:once)
        instance.send(:load_miners!)
      end

      it 'should create new instances of CgminerApiClient::Miner' do
        allow(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml])
        expect(CgminerApiClient::Miner).to receive(:new).with(mock_miner_from_yaml[:host], mock_miner_from_yaml[:port], mock_miner_from_yaml[:timeout])
        instance.send(:load_miners!)
      end

      it 'should assign the remote instances to @miners' do
        allow(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml])
        allow(CgminerApiClient::Miner).to receive(:new).with(mock_miner_from_yaml[:host], mock_miner_from_yaml[:port], mock_miner_from_yaml[:timeout]).and_return(mock_miner)
        instance.send(:load_miners!)
        expect(instance.miners).to eq [mock_miner]
      end

      context 'no port specified' do
        it 'should use the default cgminer port of 4028' do
          expect(mock_miner_from_yaml).to receive(:[]).with('port').and_return(nil)
          allow(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml])
          expect(CgminerApiClient::Miner).to receive(:new).with(mock_miner_from_yaml['host'], 4028, mock_miner_from_yaml['timeout']).and_return(mock_miner)
          instance.send(:load_miners!)
        end
      end

      context 'no timeout specified' do
        it 'should use the default timeout of 5' do
          expect(mock_miner_from_yaml).to receive(:[]).with('timeout').and_return(nil)
          allow(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml])
          expect(CgminerApiClient::Miner).to receive(:new).with(mock_miner_from_yaml['host'], mock_miner_from_yaml['port'], 5).and_return(mock_miner)
          instance.send(:load_miners!)
        end
      end
    end
  end
end