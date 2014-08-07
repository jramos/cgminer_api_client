require 'spec_helper'

describe CgminerApiClient::Miner do
  let(:host)     { '127.0.0.1' }
  let(:port)     { 4028 }
  let(:instance) { CgminerApiClient::Miner.new(host, port) }

  context 'attributes' do
    context '@host' do
      it 'should allow setting and getting' do
        instance.host = :foo
        expect(instance.host).to eq :foo
      end
    end

    context '@port' do
      it 'should allow setting and getting' do
        instance.port = :foo
        expect(instance.port).to eq :foo
      end
    end
  end

  context '#initialize' do
    it 'should raise an argument error with 0 arguments' do
      expect {
        CgminerApiClient::Miner.new
      }.to raise_error(ArgumentError)
    end

    it 'should raise an argument error with 1 argument' do
      expect {
        CgminerApiClient::Miner.new(host)
      }.to raise_error(ArgumentError)
    end

    it 'should not raise an argument error with 2 arguments' do
      expect {
        instance
      }.to_not raise_error()
    end

    it 'should set @host' do
      expect(instance.host).to eq host
    end

    it 'should set @port' do
      expect(instance.port).to eq port
    end
  end

  context '#available?' do
    context 'TCPSocket.open raises an error' do
      before do
        expect(TCPSocket).to receive(:open).and_raise(SocketError)
      end

      it 'should return false' do
        expect(instance.available?).to eq false
      end
    end

    context 'TCPSocket.open does not raise an error' do
      let(:mock_socket) { instance_double('TCPSocket') }

      before do
        expect(TCPSocket).to receive(:open).and_return(mock_socket)
      end

      context 'socket #close raises an error' do
        before do
          expect(mock_socket).to receive(:close).and_raise(SocketError)
        end

        it 'should return false' do
          expect(instance.available?).to eq false
        end
      end

      context 'socket #close does not raise an error' do
        before do
          expect(mock_socket).to receive(:close).and_return(:foo)
        end

        it 'should return true' do
          expect(instance.available?).to eq true
        end
      end
    end
  end

  context '#query' do
    context 'no parameters' do
      it 'should perform a command request' do
        expect(instance).to receive(:perform_request).with({:command => :foo}).and_return({'foo' => []})
        instance.query(:foo)
      end
    end

    context 'parameters' do
      it 'should perform a command request with parameters' do
        expect(instance).to receive(:perform_request).with({:command => :foo, :parameter => 'bar,123,\\456'}).and_return({'foo' => []})
        instance.query(:foo, :bar, :'123', :'\456')
      end
    end

    it 'should return sanitized data' do
      mock_data = double('data')
      expect(instance).to receive(:perform_request).and_return(mock_data)
      expect(instance).to receive(:sanitized).with(mock_data).and_return({:foo => []})
      expect(instance.query(:foo)).to eq []
    end

    it 'should return sanitized data for multiple commands' do
      mock_data = double('data')
      expect(instance).to receive(:perform_request).and_return(mock_data)
      expect(instance).to receive(:sanitized).with(mock_data).and_return({:foo => [], :bar => []})
      expect(instance.query('foo+bar')).to eq ({:foo => [], :bar => []})
    end
  end

  context '#method_missing' do
    before do
      allow(instance).to receive(:query).and_return(true)
    end

    it 'should query the miner with the method name' do
      expect(instance).to receive(:query).with(:foo).and_return(true)
      instance.method_missing(:foo)
    end

    it 'should pass arguments' do
      expect(instance).to receive(:query).with(:foo, [:arguments])
      instance.method_missing(:foo, [:arguments])
    end
  end

  context 'private methods' do
    context '#perform_request' do
      context 'TCPSocket cannot be opened' do
        before do
          expect(TCPSocket).to receive(:open).and_raise(SocketError)
        end

        it 'should raise an exception' do
          expect {
            instance.send(:perform_request, {})
          }.to raise_error()
        end
      end

      context 'TCPSocket can be opened' do
        let(:mock_socket) { instance_double('TCPSocket', {
          :write => true,
          :read  => "{'json':true}",
          :close => true
        }) }

        before do
          expect(TCPSocket).to receive(:open).and_return(mock_socket)
        end

        context 'single command' do
          it 'should parse the response as JSON and check the status' do
            expect(JSON).to receive(:parse).with(mock_socket.read)
            expect(instance).to receive(:check_status).and_return(true)
            instance.send(:perform_request, {})
          end
        end

        context 'multiple commands' do
          it 'should parse the response as JSON and check the status of each response element' do
            expect(JSON).to receive(:parse).with(mock_socket.read).and_return({:foo => [{'STATUS' => 'ALL_GOOD'}], :bar => [{'STATUS' => 'NOT_SO_GOOD'}]})
            expect(instance).to receive(:check_status).with({"STATUS" => 'ALL_GOOD'})
            expect(instance).to receive(:check_status).with({"STATUS" => 'NOT_SO_GOOD'})
            instance.send(:perform_request, {command: 'foo+bar'})
          end
        end
      end
    end

    context '#check_status' do
      let(:mock_response) { {} }

      context 'with successful status' do
        before do
          mock_response['STATUS'] = [{'STATUS' => 'S'}]
        end

        it 'should not log a message or raise an error' do
          expect(instance).to receive(:puts).never
          expect(instance).to receive(:raise).never
          instance.send(:check_status, mock_response)
        end
      end

      context 'with info status' do
        before do
          mock_response['STATUS'] = [{'STATUS' => 'I'}]
        end

        it 'should log a message' do
          expect(instance).to receive(:puts)
          instance.send(:check_status, mock_response)
        end
      end

      context 'with warning status' do
        before do
          mock_response['STATUS'] = [{'STATUS' => 'W'}]
        end

        it 'should log a message' do
          expect(instance).to receive(:puts)
          instance.send(:check_status, mock_response)
        end
      end

      context 'with error' do
        before do
          mock_response['STATUS'] = [{'STATUS' => 'E'}]
        end

        it 'should raise an exception' do
          expect(instance).to receive(:raise)
          instance.send(:check_status, mock_response)
        end
      end
    end

    context '#sanitized' do
      let(:mock_data) { {'Ugly Key' => :foo} }

      it 'should produce sensible output' do
        expect(instance.send(:sanitized, mock_data)).to eq ({:ugly_key => :foo})
      end
    end
  end
end