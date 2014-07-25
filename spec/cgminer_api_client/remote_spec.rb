require 'spec_helper'

describe CgminerApiClient::Remote do
  let(:host)     { '127.0.0.1' }
  let(:port)     { 4028 }
  let(:instance) { CgminerApiClient::Remote.new(host, port) }

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
        CgminerApiClient::Remote.new
      }.to raise_error(ArgumentError)
    end

    it 'should raise an argument error with 1 argument' do
      expect {
        CgminerApiClient::Remote.new(host)
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
    pending
  end

  context '#query' do
    pending
  end

  context '#method_missing' do
    pending
  end

  context 'private methods' do
    context '#perform_request' do
      pending
    end

    context '#check_status' do
      pending
    end

    context '#sanitized' do
      pending
    end
  end
end