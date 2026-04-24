# AGENTS.md — `cgminer_api_client`

Consolidated context for AI coding assistants. For end-user docs, see [`README.md`](README.md). For the release-by-release history and the 0.2.x → 0.3.0 migration guide, see [`CHANGELOG.md`](CHANGELOG.md). For deep dives on any topic below, see [`docs/`](docs/) (start with [`docs/index.md`](docs/index.md)).

## Table of contents

- [What this gem is](#what-this-gem-is)
- [Repo layout](#repo-layout) *(which files are shipped, which aren't)*
- [How the pieces fit together](#how-the-pieces-fit-together) *(one diagram + key facts)*
- [Conventions that matter when editing code](#conventions-that-matter-when-editing-code)
- [Running tests and lint](#running-tests-and-lint)
- [Adding a new cgminer command wrapper](#adding-a-new-cgminer-command-wrapper)
- [Ruby version support](#ruby-version-support)
- [Gotchas worth knowing up front](#gotchas-worth-knowing-up-front)
- [Release process](#release-process)
- [Where to look for deeper context](#where-to-look-for-deeper-context)

---

## What this gem is

<!-- metadata: overview, stack, purpose -->

A pure-Ruby client for the [cgminer](https://github.com/ckolivas/cgminer) JSON-over-TCP API. It ships as both a library and a CLI (`bin/cgminer_api_client`). Pool mode — fanning out a single command across many miners in parallel and aggregating per-miner results — is a first-class feature.

**Stack:** Ruby 3.2+ only. Zero runtime dependencies beyond Ruby stdlib (`json`, `socket`, `yaml`, `pp`). Dev deps are `rspec`, `rubocop` (+ `-rake` and `-rspec`), `rake`, `simplecov`.

**Footprint:** ~510 SLOC in `lib/`, ~3000 SLOC in `spec/`. Small, deliberately simple.

**Logging posture:** silent-by-design — the library has no `Logger` module and emits no structured events. Callers (monitor, manager, CLI) own log call sites. For telemetry during debugging there's a CLI `-v`/`--verbose` flag (prints requests + responses to stderr, operator-facing, not a parse-able contract) and a library-level `on_wire:` callback kwarg on both `Miner.new` and `MinerPool.new` (a `proc.(direction, host, port, payload)` that fires on each request / response / response-repaired event). See [`docs/logging.md`](docs/logging.md) for the full story and for how sibling gems log api_client outcomes.

## Repo layout

<!-- metadata: directory-structure, file-organization -->

```
├── bin/cgminer_api_client        # CLI (packaged in gem)
├── lib/cgminer_api_client.rb     # Entry point + module-level config (packaged)
├── lib/cgminer_api_client/
│   ├── errors.rb                 # Error < StandardError, ConnectionError, TimeoutError, ApiError
│   ├── miner.rb                  # Single-host client
│   ├── miner/commands.rb         # ReadOnly + Privileged.{Asc,Pga,Pool,System}
│   ├── miner_pool.rb             # Parallel fan-out across a pool
│   ├── miner_result.rb           # Immutable per-miner outcome (Data.define)
│   ├── pool_result.rb            # Enumerable wrapper around Array<MinerResult>
│   ├── socket_with_timeout.rb    # Non-blocking TCP connect with timeout
│   └── version.rb
├── spec/                         # RSpec unit + integration (NOT packaged)
│   ├── cgminer_api_client/       # Unit specs, one per lib file
│   ├── integration/              # cli_spec.rb spawns the real binary; miner_integration_spec hits a FakeCgminer
│   └── support/                  # FakeCgminer TCP server + canned fixture responses
├── script/fake_cgminer           # Manual sandbox; runs FakeCgminer in foreground (NOT packaged)
├── config/miners.yml.example     # Packaged; users copy to config/miners.yml
├── docs/                 # Generated docs for AI/human deep dives (version-controlled)
├── .github/workflows/ci.yml      # Ubuntu matrix: Ruby 3.2 / 3.3 / 3.4 / 4.0 / head
├── .rubocop.yml                  # TargetRubyVersion 3.2; most Metrics/* cops off
├── .rspec                        # --color --warnings --require spec_helper
├── .ruby-version                 # 4.0.2 (local dev only; gem supports 3.2+)
├── Rakefile                      # default: [spec, rubocop]
├── cgminer_api_client.gemspec
├── CHANGELOG.md                  # Keep-a-Changelog; 0.3.0 migration guide included
├── README.md
└── LICENSE.txt                   # MIT
```

**What's packaged in the gem** is controlled by the `spec.files` glob in the gemspec: `lib/**/*.rb`, `bin/*`, `config/*.example`, `README.md`, `LICENSE.txt`, `CHANGELOG.md`, `cgminer_api_client.gemspec`. Everything else (specs, scripts, CI workflows, `docs/`) is dev-only.

## How the pieces fit together

<!-- metadata: architecture, dataflow -->

```
CLI ─┐
     │
Lib ─┼──> MinerPool ──(parallel threads)──> Miner ──> socket ──> cgminer
     │       │                                │
     │       └──returns──> PoolResult         └──raises── ConnectionError | ApiError
     │                        │
     └──> Miner <──────────── └──contains──> MinerResult (success|failure, immutable)
```

**Key structural facts:**

1. **`Miner` and `MinerPool` both `include Miner::Commands`.** Same command surface, different execution shape. A method like `summary` runs against one miner on `Miner`, and against every miner in parallel on `MinerPool`.
2. **`method_missing`** on both classes forwards unknown names to `query(name, *args)`. Any cgminer API command not explicitly wrapped still works. `respond_to_missing?` on both excludes `to_*`/`_*` names so implicit-conversion probes don't get forwarded as real commands.
3. **`MinerPool#query` always returns a `PoolResult`** — an Enumerable of per-miner `MinerResult` instances in pool order. Successes and failures are both captured structurally; `MinerPool#query` never raises on a single-miner failure.
4. **`Miner#query` raises on failure:** `ConnectionError` for transport-level problems, `ApiError` for cgminer `STATUS=E`/`F` responses. `TimeoutError < ConnectionError` for connect timeouts specifically.
5. **Library code never writes to stderr.** The CLI owns that channel. `Miner#check_status` does `puts` on cgminer `STATUS=I`/`W` to stdout, which is by design (cgminer advisory messages).
6. **`on_wire:` is best-effort telemetry, not a hard contract.** The callback is invoked from `safe_on_wire` which swallows any exception raised by the block — a buggy logger must not break the miner query. Three directions: `:request` (outbound JSON), `:response` (raw inbound string, pre-parse), `:response_repaired` (the rare `}{` legacy-repair path). The CLI's `-v` flag is implemented by installing a default `on_wire` that writes formatted lines to stderr.

## Conventions that matter when editing code

<!-- metadata: coding-style, conventions, best-practices -->

### Ruby style

- **Every file starts with `# frozen_string_literal: true`.** New files must too.
- **Explicit `StandardError` in bare rescues.** `rescue StandardError => e`, not `rescue => e`. The one exception is `rescue StandardError` with no variable when you're specifically swallowing per-connection errors in `FakeCgminer` (documented in that file).
- **`String#match?` when you only need a boolean**, not `String#match` + truthy-test. `length == 0` → `empty?`. `'%04x' % x` → `format('%04x', x)`.
- **`YAML.safe_load_file`** for config loading — never `YAML.load_file`.
- **`socket.wait_writable(timeout)`**, not `IO.select(nil, [s], nil, timeout)`. Required for Fiber-scheduler compatibility.
- **`Data.define` for immutable value objects**, not `Struct` or custom classes. See `MinerResult`.

### RuboCop

- `.rubocop.yml` disables most `Metrics/*` cops (they fight the existing structure without adding value at this scale) and most `RSpec/*` style cops (existing suite uses idiomatic-for-its-time patterns). Correctness cops like `RSpec/RepeatedExample`, `RSpec/IdenticalEqualityAssertion`, `RSpec/LeakyConstantDeclaration` are **intentionally left on** — don't disable without a specific reason.
- `bundle exec rubocop -A` is fine as a starting point; `bundle exec rake` (which also runs specs) is the canonical check.

### Commit style

- **One commit per logical step.** For multi-step changes, land each step as a separate commit. Run `bundle exec rake` (specs + rubocop) before each commit.
- Use imperative mood ("Add X", "Fix Y"), kept brief. Look at recent `git log` for style.

### Error handling

- New errors should subclass one of the existing four (`Error`, `ConnectionError`, `TimeoutError`, `ApiError`) — don't add a sibling unless you have a real reason. The hierarchy is deliberate: `ConnectionError` = "couldn't reach the miner", `ApiError` = "miner answered and rejected". Keep those semantics intact.
- Rescue narrowly. `rescue SocketError, SystemCallError, CgminerApiClient::TimeoutError` in `Miner#available?` is the pattern — bugs like `ArgumentError` should propagate, not be silently swallowed.
- `MinerPool#query` worker threads use `rescue StandardError => e` deliberately — they capture everything into a `MinerResult.failure`. One bad miner must not take down the whole pool query.

### Testing

- **Unit specs live at `spec/cgminer_api_client/**`**, one file per `lib/` file. Integration specs at `spec/integration/`.
- **Integration tests use `FakeCgminer`** — a tiny in-process TCP server (`spec/support/fake_cgminer.rb`). `FakeCgminer.with { |port| ... }` brackets a block with start/stop.
- **CLI integration (`spec/integration/cli_spec.rb`) spawns the real binary** via `Open3.capture3`. Don't mock the CLI; fork it and assert on exit codes, stdout, stderr.
- **Prefer fixture-based specs to mocks** for the request/parse path. `spec/support/cgminer_fixtures.rb` has canned cgminer wire-format responses grounded in cgminer's actual `codes[]` table.
- **Test against real outputs**, not mock idealizations. Ruby 3.4 changed `pp` output for symbol-keyed hashes — don't assert on punctuation (`:k=>v` vs `k: v`); assert on semantic shape.
- **Warnings are deliberately on** (`.rspec: --warnings`). Keep the suite warning-clean.
- `config.order = :random` — specs must be order-independent.
- `mocks.verify_partial_doubles = true` — doubles must match real method signatures.

### Adding tests for a new command

Mirror the pattern in `spec/cgminer_api_client/miner/commands_spec.rb`. For a new read-only command:

```ruby
describe '#your_new_command' do
  it 'calls query(:your_new_command)' do
    expect(miner).to receive(:query).with(:your_new_command)
    miner.your_new_command
  end
end
```

For integration, add a fixture to `spec/support/cgminer_fixtures.rb` (grounded in real cgminer wire format if possible) and exercise via `FakeCgminer` in `spec/integration/miner_integration_spec.rb`.

## Running tests and lint

<!-- metadata: testing, local-dev, commands -->

```sh
bundle install
bundle exec rake                         # spec + rubocop (default task)
bundle exec rspec                        # all specs
bundle exec rspec spec/cgminer_api_client  # unit only
bundle exec rspec spec/integration         # integration only
bundle exec rspec path/to/spec.rb:123      # single example by line
bundle exec rubocop                      # lint only
bundle exec rubocop -A                   # lint + auto-correct (review diffs!)
```

**Coverage** is always on (SimpleCov in `spec_helper.rb`). Reports land in `coverage/` — don't commit that directory (it's `.gitignore`d).

**Manual sandbox** for exercising the CLI without real miners:

```sh
# terminal 1
./script/fake_cgminer              # listens on 127.0.0.1:4028
# terminal 2
cp config/miners.yml.example config/miners.yml
bundle exec bin/cgminer_api_client summary
bundle exec bin/cgminer_api_client -v summary   # verbose: echo request + response to stderr
```

## Adding a new cgminer command wrapper

<!-- metadata: extending, how-to -->

1. **Decide read-only or privileged.** Privileged commands need the miner's `allow` setting to include a `W:` (write) prefix for your IP; read-only commands don't.
2. **Pick the right sub-module** in `lib/cgminer_api_client/miner/commands.rb`:
   - Read-only → `ReadOnly`
   - Privileged ASC/PGA device op → `Privileged::Asc` or `Privileged::Pga`
   - Pool management → `Privileged::Pool`
   - Host-level → `Privileged::System`
3. **Write the wrapper as a one-liner.** Pattern for read-only:
   ```ruby
   def your_command(arg)
     query(:your_command, arg)
   end
   ```
   Pattern for privileged:
   ```ruby
   def your_command(arg)
     query(:your_command, arg) unless access_denied?
   end
   ```
   If the response is a single-element array that callers will want unwrapped, do `query(:your_command)[0]` — **but** if you add another such command, also override it in `MinerPool` so it works correctly on a pool (see the existing override block for `summary`/`coin`/`config`/`version` in `miner_pool.rb`). Without that override, pool calls will silently return only the first miner's response.
4. **Add specs** in `spec/cgminer_api_client/miner/commands_spec.rb`. If the command has interesting response parsing, add a fixture and an integration test too.
5. **Update `README.md`** — the "Commands & Arguments" section lists wrapped commands.
6. **Don't add a `CHANGELOG.md` entry for a tiny one-liner** — batch them in the release notes.

If you don't want to wrap a command explicitly, `method_missing` already handles it: `miner.anything_new('arg')` works. Wrapping is for discoverability (it shows up in `respond_to?(:method, false)` and in `Miner::Commands.instance_methods`, which the CLI validates against) and ergonomics.

## Ruby version support

<!-- metadata: runtime, compatibility -->

- **Minimum:** Ruby 3.2. Enforced by the gemspec (`required_ruby_version >= 3.2`).
- **CI matrix:** 3.2, 3.3, 3.4, 4.0 (all required), plus `head` (allowed to fail; early-warning signal).
- **Local dev pin:** `.ruby-version` says 4.0.2. Only affects contributors.

**When proposing Ruby code, verify every stdlib class/method you reference exists on 3.2.** A few sharp edges to be aware of:

- `Data.define` requires 3.2. Older Ruby literature recommends `Struct` — don't switch.
- `pp`'s symbol-keyed hash output changed in 3.4: `:k=>v` → `k: v`. The CLI integration specs handle both; if you add more CLI output specs, don't assert on exact punctuation.
- Pattern matching (`case / in`) works on 3.0+; fine on 3.2.
- `socket.wait_writable(timeout)` works on 3.0+; fine on 3.2.

## Gotchas worth knowing up front

<!-- metadata: caveats, surprises -->

These are real past-incident-shaped corners of the codebase. The CHANGELOG has the full story; keep these in mind before "cleaning up" related code:

1. **`Miner#query`'s parameter escape** uses `gsub('\\') { '\\\\' }` (block form), not `gsub('\\', '\\\\')`. The latter is a silent no-op because in gsub's replacement-string DSL, `\\` denotes a single literal backslash. There are four explicit specs locking this down — don't "simplify" back to the string form.

2. **`MinerPool#summary`/`coin`/`config`/`version`/`check` are explicitly overridden** in `miner_pool.rb`. If you remove the override block, every multi-miner pool silently loses all but the first miner's response (pre-0.3.0 bug). The tests should catch this, but don't rely on it.

3. **`Miner#available?` opens a fresh socket every call.** No cache. If that seems expensive, it's because a previous caching implementation permanently marked miners as unavailable after any transient blip. That's why the cache is gone.

4. **`Miner#query` does NOT short-circuit on `!available?`.** As of 0.3.0, it calls `perform_request` directly and lets `ConnectionError` propagate. An earlier implementation silently returned `nil` for unreachable miners and caused real operator pain.

5. **The `}{` repair in `Miner#perform_request`** is legacy defensive code that may not fire on modern cgminer. Don't remove without a repro; don't "clean up" by adding tests that pass synthetic input — add a real-cgminer repro or leave it alone. See `spec/support/cgminer_fixtures.rb` for the commentary.

6. **`config/miners.yml` is resolved relative to process CWD**, not gem install dir. Library consumers embedding `MinerPool` need to either align CWD or construct `Miner` instances directly. An entry missing `host` raises `CgminerApiClient::Error` immediately on `MinerPool.new`, so typos surface at construction time instead of silently connecting to `127.0.0.1`.

7. **Out-of-band git changes are normal.** Don't treat surprising git state (uncommitted changes you didn't make, etc.) as a tool malfunction — the maintainer makes changes outside the assistant session.

## Release process

<!-- metadata: release, publishing -->

Not automated. On a clean `master`:

```sh
bundle exec rake                                 # must pass clean
# bump version in lib/cgminer_api_client/version.rb
# update CHANGELOG.md (Keep-a-Changelog format, one section per release)
git commit -am "Release vX.Y.Z"
gem build cgminer_api_client.gemspec             # produces cgminer_api_client-X.Y.Z.gem
gem push cgminer_api_client-X.Y.Z.gem            # requires 2FA (rubygems_mfa_required=true)
git tag vX.Y.Z
git push origin master vX.Y.Z
```

The `.gem` artifact shouldn't be committed to the repo, but one is present at the root (`cgminer_api_client-0.3.0.gem`) from the 0.3.0 release as an untracked file.

## Where to look for deeper context

<!-- metadata: doc-navigation -->

| Question | File |
|---|---|
| How do the classes relate architecturally? Why `method_missing`? Why `Data.define`? | [`docs/architecture.md`](docs/architecture.md) |
| What does each class do? | [`docs/components.md`](docs/components.md) |
| What's the public method signature for X? CLI exit codes? Wire format? | [`docs/interfaces.md`](docs/interfaces.md) |
| What's in a `MinerResult` / `PoolResult`? What errors can be raised? | [`docs/data_models.md`](docs/data_models.md) |
| How does a request flow through the code? Parallel fan-out? CLI? | [`docs/workflows.md`](docs/workflows.md) |
| Runtime deps? Why Ruby 3.2+? | [`docs/dependencies.md`](docs/dependencies.md) |
| Logging posture: silent-by-design, CLI `-v`/`--verbose`, library `on_wire:` callback, how callers log outcomes | [`docs/logging.md`](docs/logging.md) |
| Known doc/code drift, caveats, things I'm not sure about | [`docs/review_notes.md`](docs/review_notes.md) |
| Full knowledge-base index | [`docs/index.md`](docs/index.md) |
| User-facing docs | [`README.md`](README.md) |
| Release history and 0.2.x→0.3.0 migration guide | [`CHANGELOG.md`](CHANGELOG.md) |
