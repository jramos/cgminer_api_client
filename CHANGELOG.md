# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`-v` / `--verbose` flag on the `cgminer_api_client` CLI.** Logs the
  JSON request and raw response to stderr, one line each, with a
  `host:port` prefix so multi-miner fan-out output stays grep-able. The
  formatted result still goes to stdout unchanged. Parsed via
  `OptionParser#permute!`, so the flag works before or after the
  command. Passwords in `addpool`, `setconfig`, `ascset`, and `pgaset`
  are replaced with `[REDACTED]` in the log output (wire bytes are
  unaffected).
- **`on_wire:` kwarg on `Miner#initialize` and `MinerPool#initialize`.**
  Library-level hook used by the CLI's `-v` flag. Accepts a Proc of
  shape `(direction, host, port, payload)` where direction is
  `:request`, `:response`, or `:response_repaired`. Default `nil` is a
  no-op; library code does not write to stderr itself.

### Changed
- **`Miner::Commands::Privileged#access_denied?`** now raises
  `CgminerApiClient::ApiError` with message `'access denied'`
  instead of a bare `RuntimeError` with message `'access_denied'`.
  Callers using `rescue CgminerApiClient::Error` or
  `rescue StandardError` are unaffected; only code that specifically
  pattern-matched on `RuntimeError` from a privileged command on an
  unprivileged miner needs to update.
- **`MinerPool#load_miners!`** now raises `CgminerApiClient::Error`
  (was `RuntimeError`) when `config/miners.yml` is missing. Existing
  `rescue StandardError` clauses still work.

### Fixed
- **`MinerPool` no longer silently defaults a miners.yml entry
  missing `host` to `CgminerApiClient.default_host`.** A typo'd
  config entry like `{port: 4028}` used to quietly produce a Miner
  pointing at `127.0.0.1`; now raises
  `CgminerApiClient::Error "config/miners.yml: entry N is missing 'host'"`
  on `MinerPool.new`.

## [0.3.0] - 2026-04-07

### Removed
- Support for Ruby 2.x and Ruby 3.1. The gem now requires Ruby 3.2 or higher.
- `Miner#query`'s short-circuit on `!available?`. `query` now calls
  `perform_request` directly and lets `ConnectionError` propagate to
  the caller. Previously an unreachable miner caused `query` to
  return `nil` silently.
- `Miner#available?`'s `force_reload` parameter. The method no
  longer caches, so the parameter is meaningless.
- `MinerPool#available_miners` and `MinerPool#unavailable_miners`
  `force_reload` parameter. Same reason.
- The host:port-prefixed stderr warning inside `MinerPool#query`
  (added earlier in the 0.3.0 cycle). Library code should not
  print unsolicited; the error is now structurally available via
  `PoolResult` and the CLI prints it explicitly.
- `pry` from the development dependencies (it was unused).
- `.travis.yml` (Travis CI is effectively deprecated for OSS Ruby).
- `.whitesource` (Mend Bolt for GitHub was sunset; if SCA is wanted
  later, configure Dependabot via `.github/dependabot.yml`).

### Added
- **`CgminerApiClient::MinerResult`** — immutable value object
  (backed by `Data.define`) wrapping a single per-miner outcome.
  Has `miner`, `value`, `error`, `ok?`, `failed?`, `raise!`,
  plus free `==`, `hash`, `eql?`, `inspect`, `to_h`, and
  `deconstruct_keys` from `Data.define` for pattern matching.
- **`CgminerApiClient::PoolResult`** — Enumerable wrapper around
  `Array<MinerResult>` returned from every `MinerPool` query.
  Preserves miner order. High-level helpers: `#values`, `#errors`,
  `#successful`, `#failed`, `#all_successful?`, `#any_succeeded?`,
  `#any_failed?`, plus `#[](key)` for lookup by index, Miner
  instance, or `"host:port"` string.
- `CgminerApiClient::Error`, `CgminerApiClient::ConnectionError`,
  `CgminerApiClient::TimeoutError` (subclass of ConnectionError),
  and `CgminerApiClient::ApiError` exception classes. All subclass
  the base `Error` which itself subclasses `StandardError`, so
  existing rescues keep working.
- `respond_to_missing?` on `Miner` and `MinerPool` so introspection
  (`respond_to?`, `Object#method`, etc.) reflects the dynamic API
  surface while excluding internal probes (`to_*`, `_*`).
- `# frozen_string_literal: true` pragma on every Ruby file.
- `required_ruby_version >= 3.2` in the gemspec.
- Gemspec metadata (`source_code_uri`, `changelog_uri`,
  `bug_tracker_uri`, `rubygems_mfa_required`).
- RuboCop with `rubocop-rspec` and `rubocop-rake` plugins,
  integrated into the default Rake task.
- GitHub Actions CI matrix testing Ruby 3.2, 3.3, 3.4, and 4.0
  (plus `head` as an early-warning, allowed to fail).
- `.ruby-version` file pinning local development to 4.0.2 (the
  gem itself supports 3.2+; the pin is only for contributors).
- `CHANGELOG.md` (this file).
- Unit test coverage brought to 99.66% on `lib/` (was 97.4% before
  the 0.3.0 work). The entire `SocketWithTimeout#open_socket`
  method, `MinerPool#available_miners`, `#unavailable_miners`,
  the thread-rescue branch in `MinerPool#query`, the control-
  character escape path in `Miner#perform_request`, and the new
  `MinerResult` / `PoolResult` value objects all have dedicated
  specs.
- End-to-end integration test suite at `spec/integration/`.
  `miner_integration_spec.rb` exercises the full request → TCP
  socket → response → parse → result path against a `FakeCgminer`
  server running in a background thread. `cli_spec.rb` spawns
  the real binary via `Open3` and asserts on exit codes,
  stdout/stderr split, and `DEBUG=1` backtrace behavior.
- `script/fake_cgminer` for manual sandbox testing. Starts the
  same fake cgminer server on a fixed port (default 4028) in the
  foreground, so you can run the CLI against it without hardware.
  Intentionally lives in `script/` rather than `bin/` so it isn't
  packaged with the gem.

### Changed
- **`MinerPool#query` now returns a `PoolResult`** instead of an
  `Array` with `[]` sentinels for failed miners. Callers iterate
  `MinerResult` instances and explicitly distinguish success from
  failure. Failed miners are no longer confused with successful
  ones returning empty arrays.
- **`MinerPool` now overrides `summary`, `coin`, `config`,
  `version`, and `check`** to return a `PoolResult` of unwrapped
  hashes. Previously these convenience methods called
  `query(:name)[0]`, which silently returned only the *first*
  miner's hash on multi-miner pools (a pre-existing latent bug).
- **`Miner#query` now raises `ConnectionError`** instead of
  returning `nil` when a miner is unreachable. Single-Miner
  callers need to rescue; MinerPool callers get the error
  captured in a `MinerResult.failure` automatically.
- **`Miner#available?` is now a true reachability probe.** No
  cache, narrow rescue list (only `SocketError`,
  `SystemCallError`, and `TimeoutError` — bugs like `ArgumentError`
  propagate). Always re-checks.
- `SocketWithTimeout` raises `CgminerApiClient::TimeoutError`
  instead of a bare `RuntimeError` on connect timeout.
- `Miner#perform_request` raises `ConnectionError` (not
  `RuntimeError`) on socket open failure, with a message that
  includes the original error class and message.
- `Miner#check_status` raises `ApiError` (not `RuntimeError`) for
  cgminer status codes `E` and `F`.
- **`bin/cgminer_api_client` redesigned**: errors go to stderr
  (not stdout), exit codes follow shell conventions (0 on any
  success, 1 on all-failure, 64/EX_USAGE on unknown command),
  `DEBUG=1` env var prints full backtraces via
  `Exception#full_message`, and output is structured per-miner
  with `host:port:` headers.
- `YAML.load_file` → `YAML.safe_load_file` for the miners config.
- `IO.select(nil, [socket], nil, timeout)` →
  `socket.wait_writable(timeout)` in `SocketWithTimeout` —
  Fiber-scheduler compatible.
- `String#match` → `String#match?` where the result is only used
  as a boolean.
- `length == 0` → `empty?`, `'%04x' %` → `format`, and other
  small modernizations.
- Bare `rescue` clauses now specify `StandardError` explicitly.
- Gemspec file list switched from `git ls-files` to explicit
  `Dir.glob` patterns; `spec/` is no longer packaged in the gem.
- Bumped minimum versions of `rake`, `rspec`, and `simplecov`.

### Fixed
- **`Miner#query` parameter escape was a silent no-op for
  backslashes.** The intent was to double literal backslashes so
  they round-trip through cgminer's comma-separated parameter
  syntax, but `gsub('\\', '\\\\')` is parsed as "replace `\` with
  `\`" because in gsub's replacement-string DSL, `\\` denotes a
  single literal backslash. Fixed by switching to
  `gsub('\\') { '\\\\' }` (block form bypasses replacement-string
  interpretation). Verified empirically; locked down by four
  explicit specs.
- **`Miner::Commands#privileged` mislabeled connection errors as
  access denied.** Previously rescued every `StandardError` and
  returned `false`, which propagated through `access_denied?` to
  raise `'access_denied'` from every privileged command
  (`addpool`, `restart`, `quit`, `save`, `ascset`, etc.) during a
  transient network outage — sending operators chasing phantom
  auth/whitelist bugs. Now rescues only `ApiError` so
  connection-layer failures surface as `ConnectionError` instead.
- **`MinerPool#summary` / `#coin` / `#config` / `#version` /
  `#check` silently returned only the first miner's hash on
  multi-miner pools.** The inherited `Miner::Commands::ReadOnly`
  methods do `query(:name)[0]` to unwrap cgminer's single-element
  response arrays, which works on a single Miner but drops every
  result except the first on a pool. Fixed by overriding all five
  on `MinerPool` to return a `PoolResult` of unwrapped hashes.
- **`Miner#available?` permanently cached `false` after any
  transient failure.** Once a brief network blip had marked a
  miner unavailable, the gem refused to talk to it for the
  lifetime of the process. Fixed by dropping the cache entirely.
- Mismatched indentation in `def privileged` that was producing a
  Ruby parser warning.

## Migration guide: 0.2.x → 0.3.0

This release intentionally contains breaking changes to finish
cleanups that were overdue. The gem is still on 0.x and only
~2,600 of 35,000 total downloads are on 0.2.6, so the
migration surface is small. Here's what to update.

### Ruby 3.2+

The gemspec now requires Ruby 3.2. If you're on 3.1 or older, you
need to upgrade Ruby before you can use this release.

### `MinerPool#query` (and all pool commands) return `PoolResult`

```ruby
# Before (0.2.x)
pool.summary.each { |s| puts s[:mhs_av] }
pool.summary.first[:mhs_av]

# After (0.3.0)
pool.summary.values.each { |s| puts s[:mhs_av] }
pool.summary.values.first[:mhs_av]

# Or iterate per-miner with failure handling:
pool.summary.each do |result|
  if result.ok?
    puts "#{result.miner.host}: #{result.value[:mhs_av]}"
  else
    warn "#{result.miner.host}: #{result.error.message}"
  end
end
```

`PoolResult` includes `Enumerable`, so `.first`, `.map`, `.count`,
`.find` etc. all work — but now they yield `MinerResult`
instances, not raw hashes. Use `.values` to get just the
successful values as an Array.

### `Miner#query` raises `ConnectionError` instead of returning `nil`

```ruby
# Before (0.2.x)
result = miner.summary
return unless result   # nil meant unreachable
puts result[:mhs_av]

# After (0.3.0)
begin
  result = miner.summary
  puts result[:mhs_av]
rescue CgminerApiClient::ConnectionError => e
  warn "miner unreachable: #{e.message}"
end
```

If you're using `MinerPool` instead of `Miner` directly, you
don't need to change anything — `MinerPool` catches the
`ConnectionError` per miner and turns it into a
`MinerResult.failure`.

### `MinerPool#summary` etc. now return every miner, not just the first

If you were calling `pool.summary` on a multi-miner pool and
relying on getting back a single Hash, you were actually being
bitten by a pre-existing bug (the result was silently dropping
every miner except the first). Now you get a `PoolResult` with
one entry per miner. Use `.values.first` if you really want
just the first miner.

### `force_reload` parameter removed

```ruby
# Before (0.2.x)
pool.available_miners(true)   # force re-check
miner.available?(true)

# After (0.3.0)
pool.available_miners         # always re-checks
miner.available?
```

There's no cache to flush anymore.

### `MinerPool#query` no longer writes to stderr

Previously, a failed per-miner query would print
`[host:port] ErrorClass: message` to stderr as a side effect of
calling `pool.query`. That was an earlier 0.3.0 addition; it's
removed because library code shouldn't print. The error is now
carried structurally in the `MinerResult.failure` inside the
`PoolResult`, and you can display it however you want. The CLI
(`bin/cgminer_api_client`) does display it on stderr.

### CLI exit codes changed

```
# Before (0.2.x)
cgminer_api_client summary     # exit 0 whether or not it worked
                                # errors written to stdout

# After (0.3.0)
cgminer_api_client summary     # exit 0 if any miner succeeded,
                                # 1 if all failed,
                                # 64 for unknown command.
                                # errors on stderr.
DEBUG=1 cgminer_api_client summary  # also prints full backtraces
```

If you had a shell pipeline that captured the CLI's stdout
expecting the whole data blob (including errors), your script
needs updating. Errors now go to stderr like they should.

### Exception class hierarchy

All gem-specific errors now inherit from
`CgminerApiClient::Error < StandardError`:

```
CgminerApiClient::Error
├── CgminerApiClient::ConnectionError
│   └── CgminerApiClient::TimeoutError
└── CgminerApiClient::ApiError
```

Existing `rescue StandardError` clauses keep working. If you
want to catch everything the gem raises, `rescue CgminerApiClient::Error`
now works.

## [0.2.6] - earlier

See git history for changes prior to 0.3.0.
