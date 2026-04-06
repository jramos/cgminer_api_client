# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::Miner do
  let(:host)     { '127.0.0.1' }
  let(:port)     { 4028 }
  let(:timeout)  { 1 }
  let(:instance) { CgminerApiClient::Miner.new(host, port, timeout) }

  context 'attributes' do
    context '@host' do
      it 'allows setting and getting' do
        instance.host = :foo
        expect(instance.host).to eq :foo
      end
    end

    context '@port' do
      it 'allows setting and getting' do
        instance.port = :foo
        expect(instance.port).to eq :foo
      end
    end

    context '@timeout' do
      it 'allows setting and getting' do
        instance.timeout = :foo
        expect(instance.timeout).to eq :foo
      end
    end
  end

  describe '#initialize' do
    it 'does not raise an argument error with 0 arguments' do
      expect do
        CgminerApiClient::Miner.new
      end.not_to raise_error
    end

    it 'does not raise an argument error with 1 arguments' do
      expect do
        CgminerApiClient::Miner.new(host)
      end.not_to raise_error
    end

    it 'does not raise an argument error with 2 arguments' do
      expect do
        CgminerApiClient::Miner.new(host, port)
      end.not_to raise_error
    end

    it 'does not raise an argument error with 3 arguments' do
      expect do
        CgminerApiClient::Miner.new(host, port, timeout)
      end.not_to raise_error
    end

    it 'uses defaults' do
      miner = CgminerApiClient::Miner.new
      expect(miner.host).to eq CgminerApiClient.default_host
      expect(miner.port).to eq CgminerApiClient.default_port
      expect(miner.timeout).to eq CgminerApiClient.default_timeout
    end

    it 'sets @host' do
      expect(instance.host).to eq host
    end

    it 'sets @port' do
      expect(instance.port).to eq port
    end

    it 'sets @timeout' do
      expect(instance.timeout).to eq timeout
    end
  end

  describe '#available?' do
    let(:mock_socket) { instance_double('Socket') }

    context 'open_socket raises an error' do
      before do
        expect(instance).to receive(:open_socket).and_raise(SocketError)
      end

      it 'returns false' do
        expect(instance.available?).to eq false
      end
    end

    context 'open_socket does not raise an error' do
      before do
        expect(instance).to receive(:open_socket).and_return(mock_socket)
      end

      context 'socket #close raises an error' do
        before do
          expect(mock_socket).to receive(:close).and_raise(SocketError)
        end

        it 'returns false' do
          expect(instance.available?).to eq false
        end
      end

      context 'socket #close does not raise an error' do
        before do
          expect(mock_socket).to receive(:close).and_return(:foo)
        end

        it 'returns true' do
          expect(instance.available?).to eq true
        end
      end
    end

    it 'sets an instance variable' do
      expect(instance).to receive(:open_socket).and_return(mock_socket)
      expect(mock_socket).to receive(:close).and_return(true)
      instance.available?
      expect(instance.instance_variable_get(:@available)).to eq true
    end
  end

  describe '#query' do
    context 'unavailable' do
      before do
        expect(instance).to receive(:available?).and_return(false)
      end

      it 'does not perform a command request' do
        expect(instance).not_to receive(:perform_request)
        instance.query(:foo)
      end

      it 'returns nil' do
        expect(instance.query(:foo)).to eq nil
      end
    end

    context 'available' do
      before do
        expect(instance).to receive(:available?).and_return(true)
      end

      context 'no parameters' do
        it 'performs a command request' do
          expect(instance).to receive(:perform_request).with({ command: :foo }).and_return({ 'foo' => [] })
          instance.query(:foo)
        end
      end

      context 'parameters' do
        it 'performs a command request with parameters' do
          expect(instance).to receive(:perform_request).with({ command: :foo,
                                                               parameter: 'bar,123,\\456' }).and_return({ 'foo' => [] })
          instance.query(:foo, :bar, :'123', :'\\456')
        end
      end

      it 'returns sanitized data' do
        mock_data = double('data')
        expect(instance).to receive(:perform_request).and_return(mock_data)
        expect(instance).to receive(:sanitized).with(mock_data).and_return({ foo: [] })
        expect(instance.query(:foo)).to eq []
      end

      it 'returns sanitized data for multiple commands' do
        mock_data = double('data')
        expect(instance).to receive(:perform_request).and_return(mock_data)
        expect(instance).to receive(:sanitized).with(mock_data).and_return({ foo: [], bar: [] })
        expect(instance.query('foo+bar')).to eq({ foo: [], bar: [] })
      end
    end
  end

  describe '#method_missing' do
    before do
      allow(instance).to receive(:query).and_return(true)
    end

    it 'queries the miner with the method name' do
      expect(instance).to receive(:query).with(:foo).and_return(true)
      instance.method_missing(:foo)
    end

    it 'passes arguments' do
      expect(instance).to receive(:query).with(:foo, [:arguments])
      instance.method_missing(:foo, [:arguments])
    end
  end

  describe '#respond_to_missing?' do
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

  context 'private methods' do
    describe '#open_socket' do
      pending
    end

    describe '#perform_request' do
      context 'Socket cannot be opened' do
        before do
          expect(instance).to receive(:open_socket).and_raise(SocketError)
        end

        it 'raises an exception' do
          expect do
            instance.send(:perform_request, {})
          end.to raise_error(RuntimeError, 'Connection to 127.0.0.1:4028 failed')
        end
      end

      context 'Socket can be opened' do
        let(:mock_socket) do
          instance_double('Socket', {
                            write: true,
                            read: "{'json':true}",
                            close: true
                          })
        end

        before do
          expect(instance).to receive(:open_socket).and_return(mock_socket)
        end

        context 'single command' do
          it 'parses the response as JSON and check the status' do
            expect(JSON).to receive(:parse).with(mock_socket.read)
            expect(instance).to receive(:check_status).and_return(true)
            instance.send(:perform_request, {})
          end
        end

        context 'multiple commands' do
          it 'parses the response as JSON and check the status of each response element' do
            expect(JSON).to receive(:parse).with(mock_socket.read).and_return({ foo: [{ 'STATUS' => 'ALL_GOOD' }],
                                                                                bar: [{ 'STATUS' => 'NOT_SO_GOOD' }] })
            expect(instance).to receive(:check_status).with({ "STATUS" => 'ALL_GOOD' })
            expect(instance).to receive(:check_status).with({ "STATUS" => 'NOT_SO_GOOD' })
            instance.send(:perform_request, { command: 'foo+bar' })
          end
        end
      end
    end

    describe '#check_status' do
      let(:mock_response) { {} }

      context 'with successful status' do
        before do
          mock_response['STATUS'] = [{ 'STATUS' => 'S' }]
        end

        it 'does not log a message or raise an error' do
          expect(instance).not_to receive(:puts)
          expect(instance).not_to receive(:raise)
          instance.send(:check_status, mock_response)
        end
      end

      context 'with info status' do
        before do
          mock_response['STATUS'] = [{ 'STATUS' => 'I' }]
        end

        it 'logs a message' do
          expect(instance).to receive(:puts)
          instance.send(:check_status, mock_response)
        end
      end

      context 'with warning status' do
        before do
          mock_response['STATUS'] = [{ 'STATUS' => 'W' }]
        end

        it 'logs a message' do
          expect(instance).to receive(:puts)
          instance.send(:check_status, mock_response)
        end
      end

      context 'with error' do
        before do
          mock_response['STATUS'] = [{ 'STATUS' => 'E' }]
        end

        it 'raises an exception' do
          expect(instance).to receive(:raise)
          instance.send(:check_status, mock_response)
        end
      end
    end

    describe '#sanitized' do
      let(:mock_data) { { 'Ugly Key' => :foo } }

      it 'produces sensible output' do
        expect(instance.send(:sanitized, mock_data)).to eq({ ugly_key: :foo })
      end
    end
  end
end
