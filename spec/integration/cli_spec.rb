# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'

# End-to-end tests for bin/cgminer_api_client. Spawns the real
# binary via Open3 against a live FakeCgminer on an ephemeral
# port, with a temporary config/miners.yml written to a tmpdir so
# the CLI's MinerPool.new finds it. Asserts on exit code,
# stdout/stderr split, and DEBUG=1 backtrace behavior.
describe 'bin/cgminer_api_client end-to-end', :integration do
  # Resolve paths up front since the specs chdir into a tmpdir.
  let(:project_root) { File.expand_path('../..', __dir__) }
  let(:cli_binary)   { File.join(project_root, 'bin', 'cgminer_api_client') }

  # Invokes the CLI with the given args in a tmpdir that contains
  # a config/miners.yml pointing at the listed miners. Returns
  # [stdout, stderr, status].
  def run_cli(args, miners:, env: {})
    Dir.mktmpdir('cli_spec') do |dir|
      Dir.mkdir(File.join(dir, 'config'))
      File.write(
        File.join(dir, 'config', 'miners.yml'),
        miners.map { |m| "- host: #{m[:host]}\n  port: #{m[:port]}\n  timeout: 2\n" }.join
      )
      Open3.capture3(env, 'ruby', '-I', File.join(project_root, 'lib'), cli_binary, *args, chdir: dir)
    end
  end

  describe 'happy path: single miner, successful query' do
    it 'prints the summary on stdout with a host:port header and exits 0' do
      FakeCgminer.with do |port|
        stdout, stderr, status = run_cli(
          %w[summary],
          miners: [{ host: '127.0.0.1', port: port }]
        )

        expect(status.exitstatus).to eq(0)
        expect(stderr).to eq('')
        expect(stdout).to include("127.0.0.1:#{port}:")
        expect(stdout).to include('mhs_av:')
      end
    end
  end

  describe 'unknown command' do
    it 'prints USAGE on stderr and exits 64' do
      stdout, stderr, status = run_cli(
        %w[nonexistent_command],
        miners: [{ host: '127.0.0.1', port: 4028 }]
      )

      expect(status.exitstatus).to eq(64)
      expect(stdout).to eq('')
      expect(stderr).to include('USAGE: cgminer_api_client')
      expect(stderr).to include('commands:')
      expect(stderr).to include('Set DEBUG=1')
    end
  end

  describe 'closed port (all miners unreachable)' do
    it 'prints the error on stderr and exits 1' do
      # Bind and immediately release to get a definitely-closed port.
      dummy = TCPServer.new('127.0.0.1', 0)
      closed_port = dummy.addr[1]
      dummy.close

      stdout, stderr, status = run_cli(
        %w[summary],
        miners: [{ host: '127.0.0.1', port: closed_port }]
      )

      expect(status.exitstatus).to eq(1)
      expect(stdout).to eq('')
      expect(stderr).to include("127.0.0.1:#{closed_port}:")
      expect(stderr).to include('ConnectionError')
    end
  end

  describe 'mixed pool: one good, one unreachable' do
    it 'exits 0, prints good miner on stdout and bad miner on stderr' do
      dummy = TCPServer.new('127.0.0.1', 0)
      closed_port = dummy.addr[1]
      dummy.close

      FakeCgminer.with do |good_port|
        stdout, stderr, status = run_cli(
          %w[summary],
          miners: [
            { host: '127.0.0.1', port: good_port },
            { host: '127.0.0.1', port: closed_port }
          ]
        )

        expect(status.exitstatus).to eq(0)
        expect(stdout).to include("127.0.0.1:#{good_port}:")
        expect(stdout).to include('mhs_av:')
        expect(stderr).to include("127.0.0.1:#{closed_port}:")
        expect(stderr).to include('ConnectionError')
      end
    end
  end

  describe 'DEBUG=1 env var' do
    it 'prints a full backtrace on top-level errors' do
      # Write a malformed config to trigger a top-level YAML error.
      Dir.mktmpdir('cli_spec') do |dir|
        Dir.mkdir(File.join(dir, 'config'))
        File.write(File.join(dir, 'config', 'miners.yml'), ':::not valid yaml:::')

        _stdout, stderr, status = Open3.capture3(
          { 'DEBUG' => '1' },
          'ruby', '-I', File.join(project_root, 'lib'),
          cli_binary, 'summary',
          chdir: dir
        )

        expect(status.exitstatus).to eq(1)
        expect(stderr).to include('cgminer_api_client:')
        # full_message output includes file:line references from the
        # backtrace — look for a library file path as a marker.
        expect(stderr).to match(%r{lib/cgminer_api_client})
      end
    end
  end
end
