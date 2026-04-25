# frozen_string_literal: true

require 'spec_helper'

# End-to-end integration tests: a real Miner instance talks to a real
# TCP socket served by CgminerTestSupport::FakeCgminer in a background thread. These
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
      CgminerTestSupport::FakeCgminer.with do |port|
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
      CgminerTestSupport::FakeCgminer.with do |port|
        result = miner_at(port).devs
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result.first).to include(asc: 0, status: 'Alive', enabled: 'Y')
        expect(result.last).to include(asc: 1, status: 'Alive')
      end
    end

    it 'parses a multi-command response and iterates per-command statuses (summary+pools)' do
      CgminerTestSupport::FakeCgminer.with do |port|
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
      responses = { 'pools' => CgminerTestSupport::Fixtures::POOLS_WITH_CONTROL_BYTE }
      CgminerTestSupport::FakeCgminer.with(responses: responses) do |port|
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
      CgminerTestSupport::FakeCgminer.with(
        responses: { 'foo' => CgminerTestSupport::Fixtures::SUMMARY },
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
      CgminerTestSupport::FakeCgminer.with(responses: {}) do |port|
        expect { miner_at(port).query(:totally_fake_command) }
          .to raise_error(CgminerApiClient::ApiError, /14: Invalid command/)
      end
    end

    it 'attaches the cgminer integer code and :invalid_command symbol on STATUS=E for an unknown command' do
      # End-to-end coverage: the wire path threads cgminer's Code 14
      # through Miner#check_status into ApiError#cgminer_code, and
      # CGMINER_CODES maps it to the :invalid_command symbol.
      # Pinned against real FakeCgminer fixture so a future Code-vs-MSG
      # firmware drift would trip a test, not silently flip dispatch.
      # Block-form raise_error matcher (not rescue-in-it) so a refactor
      # that swallowed the raise would fail this example loudly.
      CgminerTestSupport::FakeCgminer.with(responses: {}) do |port|
        expect { miner_at(port).query(:totally_fake_command) }
          .to raise_error(CgminerApiClient::ApiError) do |e|
            expect(e.message).to eq('14: Invalid command')
            expect(e.cgminer_code).to eq(14)
            expect(e.code).to eq(:invalid_command)
          end
      end
    end

    it 'returns false from #privileged when the server responds with access denied' do
      responses = CgminerTestSupport::Fixtures::DEFAULT.merge(
        'privileged' => CgminerTestSupport::Fixtures::PRIVILEGED_DENIED
      )
      CgminerTestSupport::FakeCgminer.with(responses: responses) do |port|
        expect(miner_at(port).privileged).to be(false)
      end
    end

    it 'attaches cgminer_code: 45 and code: :access_denied when query directly hits a privileged-denied response' do
      # End-to-end coverage of the wire-side access-denied path. Unlike
      # #privileged (which rescues + returns false), a direct query
      # against an admin-only command on an unprivileged miner surfaces
      # the ApiError to the caller with the cgminer integer intact.
      responses = CgminerTestSupport::Fixtures::DEFAULT.merge(
        'privileged' => CgminerTestSupport::Fixtures::PRIVILEGED_DENIED
      )
      CgminerTestSupport::FakeCgminer.with(responses: responses) do |port|
        expect { miner_at(port).query(:privileged) }
          .to raise_error(CgminerApiClient::ApiError) do |e|
            expect(e.cgminer_code).to eq(45)
            expect(e.code).to eq(:access_denied)
          end
      end
    end

    it 'reports a closed port as unavailable and raises ConnectionError from #query' do
      # Bind and immediately release to get a definitely-closed port.
      server = TCPServer.new('127.0.0.1', 0)
      closed_port = server.addr[1]
      server.close

      miner = miner_at(closed_port)
      expect(miner.available?).to be(false)
      expect { miner.query(:summary) }
        .to raise_error(CgminerApiClient::ConnectionError, /127\.0\.0\.1:#{closed_port}/)
    end
  end

  describe 'wire-level traffic: redaction is log-only, never on the wire' do
    # This spec is the safety net for a plausible regression: if some future
    # refactor accidentally sends the loggable (redacted) request on the
    # socket instead of the real one, every admin verb that ships a secret
    # (addpool password, setconfig/ascset/pgaset values) would break in
    # production while the unit specs for on_wire redaction stay green.
    # Assert against CgminerTestSupport::FakeCgminer's on_request hook, which captures the raw
    # bytes the server received.
    it 'sends the unredacted password to cgminer even when on_wire redacts it' do
      received = []
      responses = {
        'addpool' => CgminerTestSupport::Fixtures::ADDPOOL_OK,
        'privileged' => CgminerTestSupport::Fixtures::PRIVILEGED_OK
      }

      CgminerTestSupport::FakeCgminer.with(responses: responses, on_request: ->(bytes) { received << bytes }) do |port|
        logged = []
        miner = CgminerApiClient::Miner.new('127.0.0.1', port, 2,
                                            on_wire: ->(*args) { logged << args })
        miner.query(:addpool, 'stratum+tcp://p:3333', 'user', 'hunter2')

        addpool_request = received.find { |b| b.include?('addpool') }
        expect(addpool_request).to include('hunter2')
        expect(addpool_request).not_to include('[REDACTED]')

        logged_request = logged.find { |dir, _h, _p, payload| dir == :request && payload.include?('addpool') }
        logged_payload = logged_request[3]
        expect(logged_payload).to include('[REDACTED]')
        expect(logged_payload).not_to include('hunter2')
      end
    end
  end
end
