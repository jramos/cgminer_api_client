# frozen_string_literal: true

require 'spec_helper'

# End-to-end integration tests: a real Miner instance talks to a real
# TCP socket served by FakeCgminer in a background thread. These
# tests exercise the entire request → wire → response → parse →
# result path, which the mock-based unit tests can't. Every test
# here validates a distinct code path in Miner#perform_request or
# Miner#check_status.
describe 'Miner integration with a fake cgminer server' do
  def miner_at(port)
    CgminerApiClient::Miner.new('127.0.0.1', port, 2)
  end

  describe 'read-only commands' do
    it 'returns a sanitized Hash for a single-result command (summary)' do
      FakeCgminer.with do |port|
        result = miner_at(port).summary
        expect(result).to include(
          mhs_av: 56_789.12,
          elapsed: 12_345,
          accepted: 100,
          rejected: 1
        )
      end
    end

    it 'returns an Array of sanitized Hashes for an array-result command (devs)' do
      FakeCgminer.with do |port|
        result = miner_at(port).devs
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result.first).to include(asc: 0, status: 'Alive', enabled: 'Y')
        expect(result.last).to include(asc: 1, status: 'Alive')
      end
    end

    it 'parses a multi-command response and iterates per-command statuses (summary+pools)' do
      FakeCgminer.with do |port|
        result = miner_at(port).query('summary+pools')
        expect(result).to be_a(Hash)
        expect(result).to include(:summary, :pools)
        expect(result[:summary]).to be_an(Array)
        expect(result[:pools]).to be_an(Array)
        # The gem sanitizes the top-level command names but leaves
        # the inner command-data keys as Ruby symbols of the
        # lowercased versions.
        expect(result[:summary].first).to include(:summary)
        expect(result[:pools].first).to include(:pools)
      end
    end

    it 'escapes control bytes in the response before JSON parsing (pools)' do
      # The POOLS_WITH_CONTROL_BYTE fixture contains a 0x01 byte.
      # Without the gem's \uXXXX escape path, JSON.parse would reject
      # it as invalid JSON.
      responses = { 'pools' => CgminerFixtures::POOLS_WITH_CONTROL_BYTE }
      FakeCgminer.with(responses: responses) do |port|
        result = miner_at(port).pools
        expect(result).to be_an(Array)
        # The 0x01 byte is encoded as U+0001 in the parsed JSON
        # string, so the URL field contains that character.
        expect(result.first[:url]).to include("\u0001")
      end
    end
  end

  describe 'parameter escaping on the wire' do
    it 'doubles backslashes and escapes commas in outgoing parameters' do
      received = []
      FakeCgminer.with(
        responses: { 'foo' => CgminerFixtures::SUMMARY },
        on_request: ->(bytes) { received << bytes }
      ) do |port|
        miner_at(port).query(:foo, "a\\b,c")
      end

      expect(received.size).to eq(1)
      parsed = JSON.parse(received.first)
      # Input was "a\b,c" (4 chars). On the wire the backslash must
      # be doubled and the comma escaped, yielding "a\\b\,c".
      expect(parsed['command']).to eq('foo')
      expect(parsed['parameter']).to eq('a\\\\b\\,c')
    end
  end

  describe 'error handling' do
    it 'raises ApiError when the server returns STATUS=E for an unknown command' do
      FakeCgminer.with(responses: {}) do |port|
        expect { miner_at(port).query(:totally_fake_command) }
          .to raise_error(CgminerApiClient::ApiError, /14: Invalid command/)
      end
    end

    it 'returns false from #privileged when the server responds with access denied' do
      responses = CgminerFixtures::DEFAULT.merge(
        'privileged' => CgminerFixtures::PRIVILEGED_DENIED
      )
      FakeCgminer.with(responses: responses) do |port|
        expect(miner_at(port).privileged).to be(false)
      end
    end

    it 'marks a miner as unavailable when the target port is closed' do
      # Miner#query consults #available? first and returns nil
      # (without ever calling perform_request) if the miner is
      # unreachable. This is the real-socket version of the mocked
      # unit tests for #available?.
      server = TCPServer.new('127.0.0.1', 0)
      closed_port = server.addr[1]
      server.close

      miner = miner_at(closed_port)
      expect(miner.available?).to be(false)
      expect(miner.query(:summary)).to be_nil
    end

    it 'raises ConnectionError from #perform_request directly when the socket cannot be opened' do
      # Bypasses #available? to verify the ConnectionError path
      # end-to-end against a real closed socket. This locks in the
      # post-modernization typed exception — previously this would
      # have been a plain RuntimeError.
      server = TCPServer.new('127.0.0.1', 0)
      closed_port = server.addr[1]
      server.close

      miner = miner_at(closed_port)
      expect { miner.send(:perform_request, { command: :summary }) }
        .to raise_error(CgminerApiClient::ConnectionError, /127\.0\.0\.1:#{closed_port}/)
    end
  end
end
