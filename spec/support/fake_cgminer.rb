# frozen_string_literal: true

require 'json'
require 'socket'

# A tiny fake cgminer-protocol server for integration testing and
# manual sandbox use. Accepts TCP connections on an ephemeral port
# (or a caller-specified port), reads a JSON request, looks up the
# response in a fixtures hash, writes it, and closes the connection.
#
# Connection lifecycle mirrors real cgminer: the gem does
# `s.write(request.to_json)` then `s.read` (read-to-EOF), so the
# server MUST close the socket after writing the response for the
# client's read to return.
#
# Usage:
#
#   FakeCgminer.with do |port|
#     # connect a Miner to 127.0.0.1:port and make assertions
#   end
#
# With a custom response map and a request-observer callback for
# asserting on the raw bytes the server received on the wire:
#
#   received = []
#   FakeCgminer.with(
#     responses: { 'foo' => '...' },
#     on_request: ->(bytes) { received << bytes }
#   ) do |port|
#     # tests...
#   end
#   expect(received.first).to include('parameter')
class FakeCgminer
  attr_reader :port

  def initialize(responses: CgminerFixtures::DEFAULT, port: 0, on_request: nil)
    @responses = responses
    @on_request = on_request
    @server = TCPServer.new('127.0.0.1', port)
    @port = @server.addr[1]
  end

  def start
    @thread = Thread.new { accept_loop }
    self
  end

  def stop
    # Close the listening socket FIRST. On macOS, `Thread#kill` does
    # not reliably interrupt a thread blocked in a C-level `accept`
    # syscall, so join would hang forever. Closing the socket causes
    # accept to raise IOError, which the accept loop catches to
    # break out cleanly.
    @server.close unless @server.closed?
    @thread&.join
  end

  # Bracket a block with start/stop. Cleans up even if the block
  # raises. Yields the port the server is listening on.
  def self.with(**)
    server = new(**).start
    begin
      yield server.port
    ensure
      server.stop
    end
  end

  private

  def accept_loop
    loop do
      client = accept_next_client
      break if client.nil? # server socket closed from #stop

      handle_connection_safely(client)
    end
  end

  # Returns the next accepted client, or nil if the server socket
  # has been closed (which is the normal shutdown path from #stop).
  # Only exits the loop on errors that come from the listening
  # socket itself — NOT errors from client I/O, which are handled
  # separately so a bad client doesn't take down the server.
  def accept_next_client
    @server.accept
  rescue IOError, Errno::EBADF
    nil
  end

  # Handles one client connection in isolation. Any per-connection
  # error (EOFError from an immediately-closed client, JSON parse
  # failures, write errors, etc.) is swallowed so the server keeps
  # running for the next connection. This tolerance matters for
  # Miner#available? — a caller that opens a socket and immediately
  # closes it for a reachability probe produces an EOFError here,
  # which must NOT propagate. (Note: Miner#query no longer invokes
  # available? as a pre-flight since 0.3.0, but the probe pattern
  # is still part of the public surface.)
  def handle_connection_safely(client)
    handle_request(client)
  rescue StandardError
    # ignore — next connection is unaffected
  end

  def handle_request(client)
    request_bytes = read_until_parseable(client)
    @on_request&.call(request_bytes)
    request = JSON.parse(request_bytes)
    client.write(lookup_response(request['command']))
  ensure
    client&.close
  end

  # Real cgminer requests fit in a single TCP packet over loopback so
  # this is almost always a single readpartial. The loop is here for
  # correctness if a request is ever fragmented.
  def read_until_parseable(client)
    buf = +''
    loop do
      buf << client.readpartial(4096)
      return buf if complete_json?(buf)
    end
  end

  def complete_json?(buf)
    JSON.parse(buf)
    true
  rescue JSON::ParserError
    false
  end

  def lookup_response(command)
    @responses.fetch(command) { CgminerFixtures.invalid_command(command) }
  end
end
