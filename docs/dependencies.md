# Dependencies

## Runtime dependencies

**None beyond the Ruby standard library.** The gemspec declares no `add_dependency` entries. At runtime, the gem uses only:

| Stdlib module | Used by | Purpose |
|---|---|---|
| `json` | `Miner` | Parse and serialize cgminer wire-format messages |
| `socket` | `SocketWithTimeout`, `Miner` | TCP client, non-blocking connect, `socket.wait_writable` |
| `yaml` | `MinerPool` | Parse `config/miners.yml` via `YAML.safe_load_file` |
| `pp` | `bin/cgminer_api_client` | Pretty-print per-miner responses to stdout |

All four are part of the Ruby stdlib in every supported Ruby version (3.2+) and require no bundler entry.

**Implications:**
- Installing the gem pulls nothing else into the consumer's dependency tree.
- No SemVer drift from transitive deps — if the suite passes and the gem installs, it works.
- New runtime dependencies should be approached skeptically; the "zero runtime deps" posture is a deliberate design choice.

## Development dependencies

From `Gemfile`:

```ruby
group :development do
  gem 'rake',          '>= 13.2'
  gem 'rspec',         '>= 3.13'
  gem 'rubocop',       '>= 1.60'
  gem 'rubocop-rake',  '>= 0.6'
  gem 'rubocop-rspec', '>= 2.27'
  gem 'simplecov',     '>= 0.22'
end
```

### Purpose of each

| Gem | Used for |
|---|---|
| `rake` | Task runner; `Rakefile` defines `default: [spec, rubocop]`, plus `test` alias for `spec` |
| `rspec` | Test framework (unit + integration). Required by `spec_helper.rb` |
| `rubocop` | Linter. Config in `.rubocop.yml`. `TargetRubyVersion: 3.2` |
| `rubocop-rake` | RuboCop cops for Rake tasks |
| `rubocop-rspec` | RuboCop cops for RSpec style |
| `simplecov` | Code coverage. Started in `spec_helper.rb` with a single `/spec/` filter; reports to `coverage/` |

### Resolved versions (from `Gemfile.lock`)

Current lockfile pins:

- `rake 13.3.1`, `rspec 3.13.2`, `rubocop 1.86.0`, `rubocop-rspec 3.9.0`, `rubocop-rake 0.7.1`, `simplecov 0.22.0`
- Bundler: `4.0.9`

Indirect deps (from lockfile): `ast`, `diff-lcs`, `docile`, `json`, `language_server-protocol`, `lint_roller`, `parallel`, `parser`, `prism`, `racc`, `rainbow`, `regexp_parser`, `rspec-{core,expectations,mocks,support}`, `rubocop-ast`, `ruby-progressbar`, `simplecov-html`, `simplecov_json_formatter`, `unicode-display_width`, `unicode-emoji`.

`pry` was removed from development deps in 0.3.0 as unused.

## CI infrastructure

- **GitHub Actions** (`.github/workflows/ci.yml`): runs `bundle exec rake` on ubuntu-24.04 across the Ruby matrix.
- **Matrix:** 3.2, 3.3, 3.4, 4.0 (required), and `head` (allowed to fail as an early-warning signal).
- **Caching:** `ruby/setup-ruby@v1` with `bundler-cache: true` for gem caching.

Travis CI (`.travis.yml`) and WhiteSource Bolt (`.whitesource`) were removed in 0.3.0; SCA is now handled by Dependabot (`.github/dependabot.yml`, see "Dependency update strategy" below).

## Ruby version support

- **Minimum: Ruby 3.2.** Enforced by `spec.required_ruby_version = ">= 3.2"` in the gemspec.
- **Local dev pin: Ruby 4.0.2** via `.ruby-version`. Only affects contributors' shells; does not constrain gem consumers.
- **CI tests:** 3.2, 3.3, 3.4, 4.0, head.
- **Why 3.2?** `Data.define` (used by `MinerResult`) requires 3.2+. `socket.wait_writable(timeout)` requires 3.0+. Pattern matching (`in { key: }`) requires 3.0+.

**Compatibility gotchas to watch for:**
- `pp`'s output format for symbol-keyed hashes changed in Ruby 3.4 (`:k=>v` → `k: v`). The CLI integration tests (`spec/integration/cli_spec.rb`) handle both formats — don't assert on exact punctuation.
- `Data.define` is newer than most Ruby literature; if a future feature needs struct-like value types, stick with `Data.define` over custom classes or `Struct`.

## External dependencies

**cgminer itself**, obviously. The gem targets cgminer's JSON API wire format as documented in [cgminer's API-README](https://github.com/ckolivas/cgminer/blob/master/API-README). Fixtures in `spec/support/cgminer_fixtures.rb` are grounded in cgminer 4.11.1's `codes[]` table from `cgminer/api.c`. The wire format has been stable for years; breakage due to cgminer API changes is unlikely but not impossible.

## Dependency update strategy

Dependency bumps arrive automatically via Dependabot (see `.github/dependabot.yml`). Weekly runs open PRs for Bundler and GitHub Actions updates, capped at 3 open PRs per ecosystem. PRs target the `develop` branch and use `versioning-strategy: lockfile-only` — Gemfile.lock moves forward automatically, but Gemfile / gemspec `~>` bounds are never auto-widened. A human widens bounds intentionally when they're ready to adopt a new major/minor line.

Minimum version constraints in the Gemfile are intentionally set as a floor-or-above (`rake >= 13.2`, `rspec >= 3.13`, etc.) so Bundler resolves recent versions without over-constraining.

The gem's own consumers should treat `cgminer_api_client` as a zero-transitive-footprint dep — installing it adds exactly one gem to their lockfile.
