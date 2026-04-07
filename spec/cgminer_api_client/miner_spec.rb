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

    it 'does not cache between calls' do
      expect(instance).to receive(:open_socket).twice.and_return(mock_socket)
      expect(mock_socket).to receive(:close).twice.and_return(true)
      instance.available?
      instance.available?
    end

    context 'when the socket raises a TimeoutError' do
      before do
        expect(instance).to receive(:open_socket)
          .and_raise(CgminerApiClient::TimeoutError, 'timed out')
      end

      it 'returns false' do
        expect(instance.available?).to be(false)
      end
    end

    context 'when the socket raises a SystemCallError (e.g. ECONNREFUSED)' do
      before do
        expect(instance).to receive(:open_socket).and_raise(Errno::ECONNREFUSED)
      end

      it 'returns false' do
        expect(instance.available?).to be(false)
      end
    end

    context 'when a non-network error escapes from open_socket' do
      before do
        expect(instance).to receive(:open_socket).and_raise(ArgumentError, 'bad port')
      end

      it 'propagates instead of silently returning false' do
        expect { instance.available? }.to raise_error(ArgumentError, 'bad port')
      end
    end
  end

  describe '#query' do
    context 'when perform_request raises ConnectionError' do
      it 'propagates the error instead of returning nil' do
        expect(instance).to receive(:perform_request)
          .and_raise(CgminerApiClient::ConnectionError, 'unreachable')
        expect { instance.query(:foo) }
          .to raise_error(CgminerApiClient::ConnectionError, 'unreachable')
      end
    end

    context 'when perform_request succeeds' do
      context 'no parameters' do
        it 'performs a command request' do
          expect(instance).to receive(:perform_request).with({ command: :foo }).and_return({ 'foo' => [] })
          instance.query(:foo)
        end
      end

      context 'parameters' do
        it 'joins plain parameters with commas' do
          expect(instance).to receive(:perform_request)
            .with({ command: :foo, parameter: 'bar,123' })
            .and_return({ 'foo' => [] })
          instance.query(:foo, :bar, 123)
        end

        it 'escapes literal backslashes by doubling them' do
          # Input: a single literal backslash. Expected output: two literal
          # backslashes. In single-quoted Ruby source `'\\\\'` is two `\`.
          expect(instance).to receive(:perform_request)
            .with({ command: :foo, parameter: 'a\\\\b' })
            .and_return({ 'foo' => [] })
          instance.query(:foo, "a\\b")
        end

        it 'escapes literal commas with a leading backslash' do
          expect(instance).to receive(:perform_request)
            .with({ command: :foo, parameter: 'a\\,b' })
            .and_return({ 'foo' => [] })
          instance.query(:foo, 'a,b')
        end

        it 'escapes both backslashes and commas in the same parameter' do
          # Input: a\b,c → output: a\\b\,c
          expect(instance).to receive(:perform_request)
            .with({ command: :foo, parameter: 'a\\\\b\\,c' })
            .and_return({ 'foo' => [] })
          instance.query(:foo, "a\\b,c")
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

  context 'private methods' do
    describe '#open_socket' do
      let(:sockaddr) { 'packed_sockaddr' }
      let(:socket) { instance_double(Socket, setsockopt: nil, close: nil) }

      before do
        allow(Socket).to receive(:getaddrinfo).with(host, nil)
                                              .and_return([['AF_INET', nil, host, host]])
        allow(Socket).to receive(:pack_sockaddr_in).with(port, host).and_return(sockaddr)
        allow(Socket).to receive(:new).and_return(socket)
      end

      context 'when connect_nonblock succeeds immediately' do
        before do
          allow(socket).to receive(:connect_nonblock).with(sockaddr)
        end

        it 'returns the connected socket' do
          expect(instance.send(:open_socket, host, port, timeout)).to be(socket)
        end

        it 'sets TCP_NODELAY' do
          expect(socket).to receive(:setsockopt).with(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          instance.send(:open_socket, host, port, timeout)
        end

        it 'does not call wait_writable' do
          expect(socket).not_to receive(:wait_writable)
          instance.send(:open_socket, host, port, timeout)
        end
      end

      context 'when the first connect_nonblock raises IO::WaitWritable' do
        before do
          # First call raises, second call's behavior is set by sub-contexts.
          @connect_calls = 0
          allow(socket).to receive(:connect_nonblock) do |addr|
            @connect_calls += 1
            raise IO::EAGAINWaitWritable if @connect_calls == 1

            @second_connect_result&.call(addr)
          end
        end

        context 'and wait_writable returns the socket (writable in time)' do
          before do
            allow(socket).to receive(:wait_writable).with(timeout).and_return(socket)
          end

          context 'and the second connect_nonblock succeeds' do
            before do
              @second_connect_result = ->(_addr) { 0 }
            end

            it 'returns the connected socket' do
              expect(instance.send(:open_socket, host, port, timeout)).to be(socket)
            end

            it 'does not close the socket' do
              expect(socket).not_to receive(:close)
              instance.send(:open_socket, host, port, timeout)
            end
          end

          context 'and the second connect_nonblock raises Errno::EISCONN' do
            before do
              @second_connect_result = ->(_addr) { raise Errno::EISCONN }
            end

            it 'returns the connected socket (treats EISCONN as success)' do
              expect(instance.send(:open_socket, host, port, timeout)).to be(socket)
            end

            it 'does not close the socket' do
              expect(socket).not_to receive(:close)
              instance.send(:open_socket, host, port, timeout)
            end
          end

          context 'and the second connect_nonblock raises a real error' do
            before do
              @second_connect_result = ->(_addr) { raise Errno::ECONNREFUSED }
            end

            it 'closes the socket and re-raises the original error' do
              expect(socket).to receive(:close)
              expect do
                instance.send(:open_socket, host, port, timeout)
              end.to raise_error(Errno::ECONNREFUSED)
            end
          end
        end

        context 'and wait_writable returns nil (timeout)' do
          before do
            allow(socket).to receive(:wait_writable).with(timeout).and_return(nil)
          end

          it 'closes the socket and raises TimeoutError' do
            expect(socket).to receive(:close)
            expect do
              instance.send(:open_socket, host, port, timeout)
            end.to raise_error(CgminerApiClient::TimeoutError, /timed out after #{timeout}s/)
          end
        end
      end
    end

    describe '#perform_request' do
      context 'Socket cannot be opened' do
        before do
          expect(instance).to receive(:open_socket).and_raise(SocketError)
        end

        it 'raises ConnectionError including the host, port, and original error' do
          expect do
            instance.send(:perform_request, {})
          end.to raise_error(
            CgminerApiClient::ConnectionError,
            'Connection to 127.0.0.1:4028 failed: SocketError: SocketError'
          )
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

        context 'with control characters in the response' do
          let(:mock_socket) do
            instance_double(Socket, write: true, read: "{\"x\":\"a\x01b\x1fc\"}", close: true)
          end

          it 'escapes non-printable bytes as \\uXXXX before parsing' do
            expect(JSON).to receive(:parse).with('{"x":"a\\u0001b\\u001fc"}').and_return({})
            expect(instance).to receive(:check_status).and_return(true)
            instance.send(:perform_request, {})
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

      context 'with error status' do
        before do
          mock_response['STATUS'] = [{ 'STATUS' => 'E', 'Code' => 45, 'Msg' => 'Access denied' }]
        end

        it 'raises ApiError with the cgminer code and message' do
          expect do
            instance.send(:check_status, mock_response)
          end.to raise_error(CgminerApiClient::ApiError, '45: Access denied')
        end
      end

      context 'with fatal status' do
        before do
          mock_response['STATUS'] = [{ 'STATUS' => 'F', 'Code' => 23, 'Msg' => 'Bad command' }]
        end

        it 'raises ApiError' do
          expect do
            instance.send(:check_status, mock_response)
          end.to raise_error(CgminerApiClient::ApiError, '23: Bad command')
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
