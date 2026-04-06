# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-04-06

### Removed
- Support for Ruby 2.x. The gem now requires Ruby 3.1 or higher.
- `.travis.yml` (Travis CI is effectively deprecated for OSS Ruby).
- `.whitesource` (Mend Bolt for GitHub was sunset).

### Added
- `respond_to_missing?` on `Miner` and `MinerPool` so introspection
  (`respond_to?`, `Object#method`, etc.) reflects the dynamic API
  surface, while excluding internal probes (`to_*`, `_*`).
- `# frozen_string_literal: true` pragma on every Ruby file.
- `required_ruby_version >= 3.1` in the gemspec.
- Gemspec metadata (`source_code_uri`, `changelog_uri`,
  `bug_tracker_uri`, `rubygems_mfa_required`).
- RuboCop with rubocop-rspec and rubocop-rake plugins, integrated
  into the default Rake task.
- GitHub Actions CI matrix testing Ruby 3.1, 3.2, 3.3, 3.4, and 4.0.
- `.ruby-version` file for local development.
- `CHANGELOG.md` (this file).

### Changed
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
- Dropped `pry` from the development dependencies (unused).
- Bumped minimum versions of `rake`, `rspec`, and `simplecov`.

### Fixed
- Mismatched indentation in `def privileged` that was producing a
  Ruby parser warning.

## [0.2.6] - earlier

See git history for changes prior to 0.3.0.
