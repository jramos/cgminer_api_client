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
      allow(available_miner).to receive(:available?).and_return(true)
      allow(unavailable_miner).to receive(:available?).and_return(false)
      expect(instance.available_miners).to eq([available_miner])
    end

    it 'returns an empty array if no miners are available' do
      allow(available_miner).to receive(:available?).and_return(false)
      allow(unavailable_miner).to receive(:available?).and_return(false)
      expect(instance.available_miners).to eq([])
    end

    it 'treats a network error raised from available? as unavailable (defensive rescue)' do
      allow(available_miner).to receive(:available?).and_raise(Errno::ECONNREFUSED)
      allow(unavailable_miner).to receive(:available?).and_return(true)
      expect(instance.available_miners).to eq([unavailable_miner])
    end

    it 'lets non-network bugs from available? propagate (NoMethodError, ArgumentError, etc.)' do
      allow(available_miner).to receive(:available?).and_raise(ArgumentError, 'boom')
      allow(unavailable_miner).to receive(:available?).and_return(true)
      expect { instance.available_miners }.to raise_error(ArgumentError, 'boom')
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

    it 'returns a PoolResult' do
      allow(mock_miner).to receive(:query).with(:foo).and_return({ foo: :ok })
      expect(instance.query(:foo)).to be_a(CgminerApiClient::PoolResult)
    end

    it 'wraps a successful miner response as MinerResult.success' do
      allow(mock_miner).to receive(:query).with(:foo).and_return(:ok)
      result = instance.query(:foo)
      expect(result.size).to eq(1)
      expect(result.first).to be_ok
      expect(result.first.value).to eq(:ok)
      expect(result.first.miner).to eq(mock_miner)
    end

    it 'wraps a raising miner as MinerResult.failure and does NOT write to stderr' do
      err = StandardError.new('boom')
      allow(mock_miner).to receive(:query).with(:foo).and_raise(err)
      expect(instance).not_to receive(:warn)
      result = instance.query(:foo)
      expect(result.size).to eq(1)
      expect(result.first).to be_failed
      expect(result.first.error).to eq(err)
      expect(result.first.miner).to eq(mock_miner)
    end

    it 'collects successes and failures across miners independently, preserving order' do
      ok_miner = instance_double('CgminerApiClient::Miner', host: '10.0.0.1', port: 4028)
      bad_miner = instance_double('CgminerApiClient::Miner', host: '10.0.0.2', port: 4028)
      instance.instance_variable_set(:@miners, [ok_miner, bad_miner])
      allow(ok_miner).to receive(:query).with(:foo).and_return(:ok)
      allow(bad_miner).to receive(:query).with(:foo).and_raise(StandardError, 'boom')

      result = instance.query(:foo)
      expect(result.size).to eq(2)
      expect(result[0].miner).to eq(ok_miner)
      expect(result[0].value).to eq(:ok)
      expect(result[1].miner).to eq(bad_miner)
      expect(result[1].error.message).to eq('boom')
      expect(result.values).to eq([:ok])
      expect(result.errors.map(&:message)).to eq(['boom'])
      expect(result.any_succeeded?).to be(true)
      expect(result.any_failed?).to be(true)
    end
  end

  describe 'unwrapped convenience methods' do
    let(:ok_miner)  { instance_double('CgminerApiClient::Miner', host: '10.0.0.1', port: 4028) }
    let(:bad_miner) { instance_double('CgminerApiClient::Miner', host: '10.0.0.2', port: 4028) }

    before do
      allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
      allow_any_instance_of(CgminerApiClient::MinerPool).to receive(:load_miners!).and_return(true)
      instance.instance_variable_set(:@miners, [ok_miner, bad_miner])
    end

    shared_examples 'unwraps single-element arrays per miner' do |cmd, *args|
      it "returns a PoolResult of unwrapped hashes for ##{cmd}" do
        allow(ok_miner).to receive(:query).with(cmd, *args).and_return([{ a: 1 }])
        allow(bad_miner).to receive(:query).with(cmd, *args).and_raise(StandardError, 'boom')

        result = instance.public_send(cmd, *args)
        expect(result).to be_a(CgminerApiClient::PoolResult)
        expect(result.size).to eq(2)
        expect(result.values).to eq([{ a: 1 }])
        expect(result[0].value).to eq({ a: 1 })
        expect(result[1]).to be_failed
      end
    end

    it_behaves_like 'unwraps single-element arrays per miner', :summary
    it_behaves_like 'unwraps single-element arrays per miner', :coin
    it_behaves_like 'unwraps single-element arrays per miner', :config
    it_behaves_like 'unwraps single-element arrays per miner', :version
    it_behaves_like 'unwraps single-element arrays per miner', :check, :some_subcommand
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

        it 'raises CgminerApiClient::Error' do
          expect do
            instance
          end.to raise_error(CgminerApiClient::Error, 'Please create config/miners.yml')
        end
      end

      context 'with an entry missing host' do
        before do
          allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml')
            .and_return([{ 'host' => '10.0.0.1' }, { 'port' => 4028 }])
        end

        it 'raises CgminerApiClient::Error naming the offending index' do
          expect { instance }.to raise_error(
            CgminerApiClient::Error,
            "config/miners.yml: entry 1 is missing 'host'"
          )
        end
      end

      context 'with a non-Hash entry' do
        before do
          allow(File).to receive(:exist?).with('config/miners.yml').and_return(true)
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return(['bogus'])
        end

        it 'raises CgminerApiClient::Error' do
          expect { instance }.to raise_error(CgminerApiClient::Error)
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
          expect(CgminerApiClient::Miner).to receive(:new).with(host, port, timeout, on_wire: nil)
          instance.send(:load_miners!)
        end

        it 'assigns the new Miner instances to @miners' do
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return([miner_config])
          allow(CgminerApiClient::Miner).to receive(:new).with(host, port, timeout, on_wire: nil).and_return(mock_miner)
          instance.send(:load_miners!)
          expect(instance.miners).to eq [mock_miner]
        end

        it 'threads a non-nil on_wire callback through as the same Proc' do
          # The CLI builds one mutex-wrapped lambda and expects every
          # Miner in the pool to share it so the mutex serializes
          # writes across miners. If the pool ever wraps or dup'd the
          # callback per miner, the mutex would lose its pool-wide
          # scope and multi-miner logs could tear mid-line.
          callback = ->(*) {}
          allow(YAML).to receive(:safe_load_file)
            .with('config/miners.yml').and_return([miner_config])
          expect(CgminerApiClient::Miner).to receive(:new).with(host, port, timeout, on_wire: callback)
          CgminerApiClient::MinerPool.new(on_wire: callback)
        end
      end
    end
  end
end
