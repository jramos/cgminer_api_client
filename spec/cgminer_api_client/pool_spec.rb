require 'spec_helper'

describe CgminerApiClient::Pool do
  let(:mock_remote_api_client) { instance_double('CgminerApiClient::Remote') }
  let(:mock_miner_from_yaml)   { double('miner_from_yaml', :[] => {:host => '127.0.0.1', :port => 4028} ) }
  let(:instance)               { CgminerApiClient::Pool.new }

  before do
    allow(CgminerApiClient::Remote).to receive(:new).and_return(mock_remote_api_client)
  end

  context 'attributes' do
    context '@miners' do
      it 'should allow setting and getting' do
        subject.miners = :foo
        expect(subject.miners).to eq :foo
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
        expect {
          instance
        }.to_not raise_error()
      end
    end
  end

  context '#query' do
    before do
      allow(instance).to receive(:load_miners!).and_return(true)
      instance.instance_variable_set(:@miners, [mock_remote_api_client])
    end

    it 'should run provided query on each miner' do
      expect(mock_remote_api_client).to receive(:query).with(:foo, anything)
      instance.query(:foo)
    end

    it 'should pass parameters' do
      expect(mock_remote_api_client).to receive(:query).with(:foo, [:parameters])
      instance.query(:foo, :parameters)
    end

    it 'should return an array' do
      allow(mock_remote_api_client).to receive(:query).with(:foo, anything)
      expect(instance.query(:foo)).to be_kind_of(Array)
    end
  end

  context '#method_missing' do
    before do
      allow(instance).to receive(:query).and_return(true)
    end

    it 'should query each miner with the method name' do
      expect(instance).to receive(:query).with(:foo).and_return(true)
      instance.method_missing(:foo)
    end

    it 'should pass arguments' do
      instance.method_missing(:foo, [:arguments])
    end
  end

  context 'private methods' do
    context '#load_miners!' do
      it 'should parse the configuration file' do
        expect(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml]).at_least(:once)
        instance.send(:load_miners!)
      end

      it 'should create new instances of CgminerApiClient::Remote' do
        allow(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml])
        expect(CgminerApiClient::Remote).to receive(:new).with(mock_miner_from_yaml[:host], mock_miner_from_yaml[:port])
        instance.send(:load_miners!)
      end

      it 'should assign the remote instances to @miners' do
        allow(YAML).to receive(:load_file).with('config/miners.yml').and_return([mock_miner_from_yaml])
        allow(CgminerApiClient::Remote).to receive(:new).with(mock_miner_from_yaml[:host], mock_miner_from_yaml[:port]).and_return(mock_remote_api_client)
        instance.send(:load_miners!)
        expect(instance.miners).to eq [mock_remote_api_client]
      end
    end
  end
end