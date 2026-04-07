# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-04-06

### Removed
- Support for Ruby 2.x. The gem now requires Ruby 3.1 or higher.
- `pry` from the development dependencies (it was unused).
- `.travis.yml` (Travis CI is effectively deprecated for OSS Ruby).
- `.whitesource` (Mend Bolt for GitHub was sunset; if SCA is wanted
  later, configure Dependabot via `.github/dependabot.yml`).

### Added
- `CgminerApiClient::Error`, `CgminerApiClient::ConnectionError`, and
  `CgminerApiClient::ApiError` exception classes for distinguishing
  transport-level failures from API-level rejections. Both subclass
  the new base `Error`, which itself subclasses `StandardError`, so
  existing rescues continue to work.
- `respond_to_missing?` on `Miner` and `MinerPool` so introspection
  (`respond_to?`, `Object#method`, etc.) reflects the dynamic API
  surface, while excluding internal probes (`to_*`, `_*`).
- `# frozen_string_literal: true` pragma on every Ruby file.
- `required_ruby_version >= 3.1` in the gemspec.
- Gemspec metadata (`source_code_uri`, `changelog_uri`,
  `bug_tracker_uri`, `rubygems_mfa_required`).
- RuboCop with `rubocop-rspec` and `rubocop-rake` plugins, integrated
  into the default Rake task.
- GitHub Actions CI matrix testing Ruby 3.1, 3.2, 3.3, 3.4, and 4.0
  (plus `head` as an early-warning, allowed to fail).
- `.ruby-version` file pinning local development to 4.0.2 (the gem
  itself supports 3.1+; the pin is only for contributors).
- `CHANGELOG.md` (this file).
- 23 new specs covering previously-untested branches: the entire
  `SocketWithTimeout#open_socket` method, `MinerPool#available_miners`
  / `#unavailable_miners`, the `MinerPool#query` thread-rescue
  branch, the control-character escape path in `Miner#perform_request`,
  and a broadened `respond_to_missing?` cross-check.

### Changed
- `Miner#perform_request` now raises `ConnectionError` (was a plain
  `RuntimeError`) on socket open failure, and the error message
  includes the original error class and message so the underlying
  cause isn't discarded.
- `Miner#check_status` now raises `ApiError` (was a plain
  `RuntimeError`) for cgminer status codes `E` and `F`.
- `MinerPool#query` warning output now includes the failing miner's
  host and port, e.g. `[10.0.0.5:4028] CgminerApiClient::ConnectionError: ...`.
- `YAML.load_file` → `YAML.safe_load_file` for the miners config
  (defensive; the existing config schema is already safe-loadable).
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
- **`Miner#query` parameter escape was a silent no-op for backslashes.**
  The intent was to double literal backslashes so they round-trip
  through cgminer's comma-separated parameter syntax, but
  `gsub('\\', '\\\\')` is parsed as "replace `\` with `\`" because
  in gsub's replacement-string DSL, `\\` denotes a single literal
  backslash. Fixed by switching to `gsub('\\') { '\\\\' }` (block
  form bypasses replacement-string interpretation). Verified
  empirically; locked down by four explicit specs.
- **`Miner::Commands#privileged` mislabeled connection errors as
  access denied.** Previously rescued every `StandardError` and
  returned `false`, which propagated through `access_denied?` to
  raise `'access_denied'` from every privileged command (`addpool`,
  `restart`, `quit`, `save`, `ascset`, etc.) during a transient
  network outage — sending operators chasing phantom auth/whitelist
  bugs. Now rescues only `ApiError` so connection-layer failures
  surface as `ConnectionError` instead.
- Mismatched indentation in `def privileged` that was producing a
  Ruby parser warning.

### Known limitations
- `MinerPool#query` returns `[]` as a sentinel for any per-miner
  failure. This is type-incorrect for commands that normally return
  a Hash (e.g. `summary`, `config`) and indistinguishable from a
  legitimately empty Array result for commands like `devs` or
  `pools`. The host:port-prefixed stderr warning is the only
  reliable failure signal. Fixing this requires an API change to
  the return shape and is deferred to 0.4.0.
- `Miner#available?` caches its result in `@available` and never
  re-evaluates unless `force_reload` is passed. Once a transient
  network failure has marked a miner unavailable, the gem will keep
  it marked that way for the lifetime of the process. Deferred to
  0.4.0.
- `bin/cgminer_api_client` exits 0 on failure and writes errors to
  stdout. Shell pipelines and monitoring jobs cannot detect failure.
  Deferred to 0.4.0.

## [0.2.6] - earlier

See git history for changes prior to 0.3.0.
