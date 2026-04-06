# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::MinerPool do
  let(:mock_miner)           { instance_double('CgminerApiClient::Miner') }
  let(:host)                 { '127.0.0.1' }
  let(:port)                 { 1234 }
  let(:timeout)              { 10 }
  let(:mock_miner_from_yaml) do
    double('miner_from_yaml', :[] => { 'host' => host, 'port' => port, 'timeout' => timeout })
  end
  let(:instance) { CgminerApiClient::MinerPool.new }

  before do
    allow(CgminerApiClient::Miner).to receive(:new).and_return(mock_miner)
  end

  context 'attributes' do
    context '@miners' do
      before do
        allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
        allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      end

      it 'allows setting and getting' do
        instance.miners = :foo
        expect(instance.miners).to eq :foo
      end
    end
  end

  describe '#initialize' do
    it 'loads miners' do
      expect_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!)
      instance
    end
  end

  describe '#available_miners' do
    it 'should not include unavailable miners'
    it 'should include available miners'
  end

  describe '#query' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      allow(instance).to receive(:load_miners!).and_return(true)
      instance.instance_variable_set(:@miners, [mock_miner])
    end

    it 'runs provided query on each miner' do
      expect(mock_miner).to receive(:query).with(:foo)
      instance.query(:foo)
    end

    it 'passes parameters' do
      expect(mock_miner).to receive(:query).with(:foo, :parameters)
      instance.query(:foo, :parameters)
    end

    it 'returns an array' do
      allow(mock_miner).to receive(:query).with(:foo)
      expect(instance.query(:foo)).to be_a(Array)
    end
  end

  describe '#method_missing' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      allow(instance).to receive(:query).and_return(true)
    end

    it 'queries each miner with the method name' do
      expect(instance).to receive(:query).with(:foo).and_return(true)
      instance.method_missing(:foo)
    end

    it 'passes arguments' do
      expect(instance).to receive(:query).with(:foo, [:arguments])
      instance.method_missing(:foo, [:arguments])
    end
  end

  describe '#respond_to_missing?' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
    end

    it 'returns true for arbitrary cgminer command names' do
      expect(instance.respond_to?(:devs)).to be true
      expect(instance.respond_to?(:summary)).to be true
      expect(instance.respond_to?(:any_arbitrary_command)).to be true
    end

    it 'returns false for to_* conversion methods' do
      expect(instance.respond_to?(:to_ary)).to be false
      expect(instance.respond_to?(:to_str)).to be false
      expect(instance.respond_to?(:to_int)).to be false
    end

    it 'returns false for underscore-prefixed names' do
      expect(instance.respond_to?(:_internal)).to be false
    end
  end

  describe '#reload_miners!' do
    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
    end

    it 'calls load_miners!' do
      expect(instance).to receive(:load_miners!)
      instance.reload_miners!
    end
  end

  context 'private methods' do
    describe '#load_miners!' do
      context 'without configuration file' do
        before do
          expect(File).to receive(:exist?).with('config/miners.yml').and_return(false)
        end

        it 'raises an error' do
          expect do
            instance
          end.to raise_error(RuntimeError)
        end
      end

      context 'with configuration file' do
        before do
          allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
        end

        it 'parses the configuration file' do
          expect(YAML).to receive(:safe_load_file)
            .with('config/miners.yml')
            .and_return([mock_miner_from_yaml])
            .at_least(:once)
          instance.send(:load_miners!)
        end

        it 'creates new instances of CgminerApiClient::Miner' do
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return([mock_miner_from_yaml])
          expect(CgminerApiClient::Miner).to receive(:new).with(
            mock_miner_from_yaml[:host],
            mock_miner_from_yaml[:port],
            mock_miner_from_yaml[:timeout]
          )
          instance.send(:load_miners!)
        end

        it 'assigns the remote instances to @miners' do
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return([mock_miner_from_yaml])
          allow(CgminerApiClient::Miner).to receive(:new).with(
            mock_miner_from_yaml[:host],
            mock_miner_from_yaml[:port],
            mock_miner_from_yaml[:timeout]
          ).and_return(mock_miner)
          instance.send(:load_miners!)
          expect(instance.miners).to eq [mock_miner]
        end
      end
    end
  end
end
