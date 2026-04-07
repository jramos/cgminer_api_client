# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::MinerPool do
  let(:mock_miner)   { instance_double('CgminerApiClient::Miner', host: host, port: port) }
  let(:host)         { '127.0.0.1' }
  let(:port)         { 1234 }
  let(:timeout)      { 10 }
  let(:miner_config) { { 'host' => host, 'port' => port, 'timeout' => timeout } }
  let(:instance)     { CgminerApiClient::MinerPool.new }

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
    let(:available_miner)   { instance_double('CgminerApiClient::Miner', host: '10.0.0.1', port: 4028) }
    let(:unavailable_miner) { instance_double('CgminerApiClient::Miner', host: '10.0.0.2', port: 4028) }

    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      instance.instance_variable_set(:@miners, [available_miner, unavailable_miner])
    end

    it 'includes only miners whose available? returns truthy' do
      allow(available_miner).to receive(:available?).with(false).and_return(true)
      allow(unavailable_miner).to receive(:available?).with(false).and_return(false)
      expect(instance.available_miners).to eq([available_miner])
    end

    it 'forwards force_reload to Miner#available?' do
      expect(available_miner).to receive(:available?).with(true).and_return(true)
      expect(unavailable_miner).to receive(:available?).with(true).and_return(false)
      instance.available_miners(true)
    end

    it 'returns an empty array if no miners are available' do
      allow(available_miner).to receive(:available?).and_return(false)
      allow(unavailable_miner).to receive(:available?).and_return(false)
      expect(instance.available_miners).to eq([])
    end

    it 'treats a raising available? as unavailable' do
      allow(available_miner).to receive(:available?).and_raise(StandardError, 'boom')
      allow(unavailable_miner).to receive(:available?).and_return(true)
      expect(instance.available_miners).to eq([unavailable_miner])
    end
  end

  describe '#unavailable_miners' do
    let(:miner_a) { instance_double('CgminerApiClient::Miner', host: '10.0.0.1', port: 4028) }
    let(:miner_b) { instance_double('CgminerApiClient::Miner', host: '10.0.0.2', port: 4028) }

    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      instance.instance_variable_set(:@miners, [miner_a, miner_b])
    end

    it 'returns the set difference between all miners and available miners' do
      allow(miner_a).to receive(:available?).and_return(true)
      allow(miner_b).to receive(:available?).and_return(false)
      expect(instance.unavailable_miners).to eq([miner_b])
    end

    it 'returns an empty array if all miners are available' do
      allow(miner_a).to receive(:available?).and_return(true)
      allow(miner_b).to receive(:available?).and_return(true)
      expect(instance.unavailable_miners).to eq([])
    end
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

    it 'returns [] for a miner whose query raises and emits a warning' do
      allow(mock_miner).to receive(:query).with(:foo).and_raise(StandardError, 'boom')
      expect(instance).to receive(:warn).with(a_string_matching(/StandardError.*boom/))
      expect(instance.query(:foo)).to eq([[]])
    end

    it 'collects results across miners independently' do
      ok_miner = instance_double('CgminerApiClient::Miner', host: '10.0.0.1', port: 4028)
      bad_miner = instance_double('CgminerApiClient::Miner', host: '10.0.0.2', port: 4028)
      instance.instance_variable_set(:@miners, [ok_miner, bad_miner])
      allow(ok_miner).to receive(:query).with(:foo).and_return(:ok)
      allow(bad_miner).to receive(:query).with(:foo).and_raise(StandardError, 'boom')
      allow(instance).to receive(:warn)
      expect(instance.query(:foo)).to eq([:ok, []])
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

    it 'returns false for all implicit conversion methods' do
      %i[to_ary to_str to_int to_hash to_a to_proc to_io to_path to_regexp].each do |m|
        expect(instance.respond_to?(m)).to be(false), "expected respond_to?(#{m.inspect}) to be false"
      end
    end

    it 'returns false for underscore-prefixed names' do
      expect(instance.respond_to?(:_internal)).to be false
    end

    it 'allows Method objects to be obtained for dynamic commands' do
      expect { instance.method(:any_arbitrary_command) }.not_to raise_error
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
            .and_return([miner_config])
            .at_least(:once)
          instance.send(:load_miners!)
        end

        it 'creates a Miner from each entry, passing host/port/timeout positionally' do
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return([miner_config])
          expect(CgminerApiClient::Miner).to receive(:new).with(host, port, timeout)
          instance.send(:load_miners!)
        end

        it 'assigns the new Miner instances to @miners' do
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return([miner_config])
          allow(CgminerApiClient::Miner).to receive(:new).with(host, port, timeout).and_return(mock_miner)
          instance.send(:load_miners!)
          expect(instance.miners).to eq [mock_miner]
        end
      end
    end
  end
end
