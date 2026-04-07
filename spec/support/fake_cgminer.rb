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
    @thread&.kill
    @thread&.join
    @server.close unless @server.closed?
  end

  # Bracket a block with start/stop. Cleans up even if the block
  # raises. Yields the port the server is listening on.
  def self.with(**opts)
    server = new(**opts).start
    begin
      yield server.port
    ensure
      server.stop
    end
  end

  private

  def accept_loop
    loop do
      client = @server.accept
      handle_request(client)
    rescue IOError, Errno::EBADF
      # Server socket was closed — exit the accept loop.
      break
    rescue StandardError
      # Swallow per-connection errors so one bad request doesn't
      # take down the whole server thread.
      next
    end
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
