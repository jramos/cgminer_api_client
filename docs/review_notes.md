# Review Notes

Self-audit of the documentation set. This file is where I record what I'm **not** certain about, what I glossed over, and where the documentation and the code could drift. Read this before trusting a confident-sounding claim elsewhere in `docs/summary/`.

## Consistency check

I cross-referenced the following claims across files and found no outright contradictions:

| Claim | Asserted in | Verified |
|---|---|---|
| `MinerPool#query` returns `PoolResult`, not an Array | `architecture.md`, `components.md`, `interfaces.md`, `data_models.md`, `workflows.md` | consistent |
| `MinerResult` is an immutable `Data.define` | `architecture.md`, `components.md`, `data_models.md` | consistent |
| Error hierarchy (`Error → ConnectionError → TimeoutError`, `Error → ApiError`) | `architecture.md`, `components.md`, `interfaces.md`, `data_models.md` | consistent |
| CLI exit code 0 on partial success, 1 on all-fail, 64 on usage | `architecture.md`, `interfaces.md`, `workflows.md` | consistent |
| Library code never writes to stderr | `architecture.md`, `interfaces.md`, `workflows.md` | consistent |
| Single-miner response unwrap is overridden on `MinerPool` for `summary`/`coin`/`config`/`version`/`check` | `architecture.md`, `components.md`, `workflows.md` | consistent |
| No runtime dependencies beyond stdlib | `codebase_info.md`, `architecture.md`, `dependencies.md` | consistent |
| Ruby 3.2+ minimum, CI matrix 3.2/3.3/3.4/4.0/head | `codebase_info.md`, `dependencies.md` | consistent |

Nothing I flagged as contradictory. If later edits introduce a drift, re-run this section.

## Completeness gaps

The following areas are **not fully covered** by the code and therefore not fully covered by the docs:

### 1. Thread safety of `MinerPool` is unspecified
`MinerPool#query` spawns threads and joins them before returning, so one call is self-contained. But the code doesn't document what happens if:
- Two callers invoke `pool.query(...)` on the same instance concurrently.
- A caller invokes `pool.reload_miners!` while another is mid-`query`.

Reading the code, `@miners` is reassigned by `reload_miners!` — a concurrent `query` could in principle iterate a partially-replaced array, or a mix of old and new `Miner` instances. There's no mutex. In practice, the typical usage is single-threaded script or CLI, so this hasn't bitten anyone. If `MinerPool` starts being used from servers or schedulers, this deserves a real answer.

### 2. Fiber-scheduler compatibility is claimed but not exercised
`SocketWithTimeout` switched from `IO.select` to `socket.wait_writable(timeout)` in 0.3.0 specifically to be Fiber-scheduler compatible. I stated this in `architecture.md` and `components.md`. There are no tests that actually run the gem under a Fiber scheduler, so "compatible" here means "uses APIs that are compatible" rather than "verified compatible." A future contributor running under `Async` or Ruby's default scheduler should be prepared to re-verify.

### 3. The `}{` → `}, {` repair in `Miner#perform_request` may be dead code
The fixture file (`spec/support/cgminer_fixtures.rb`) flags this directly: the repair "does not actually produce valid JSON from any format I can reproduce, and may be legacy defensive code for a cgminer version that no longer exists." I repeated the claim in `architecture.md` and `interfaces.md`. Not tested with a real cgminer binary; historical reason unknown. Before removing, add a repro fixture that definitively shows the repair fires.

### 4. The `[,{` repair has even less explanation
Same code path (`response.gsub! '[,{', '[ {'`). Fires even more rarely than `}{`. Neither repair has a dedicated test. Mentioned briefly in `architecture.md` and `interfaces.md`; treated as legacy.

### 5. `method_missing`'s scope for `MinerPool` is subtle
`MinerPool#method_missing` forwards to `query(name, *args)`, which returns a `PoolResult`. That means calling an unwrapped cgminer command on a `MinerPool` gives you a `PoolResult` whose `value`s are the raw `Hash` envelopes — the five convenience overrides (`summary`/`coin`/`config`/`version`/`check`) are the only paths that unwrap. This is correct and mentioned in `interfaces.md`, but a reader might expect `method_missing` to do something similar for every "looks like it returns one hash" command. It doesn't, and that's by design — the gem can't know the shape of an arbitrary cgminer command's response at call time.

### 6. No coverage of `config/miners.yml` path resolution edge cases
`MinerPool.new` hard-codes `'config/miners.yml'` as a relative path. Docs mention it's relative to process CWD. Not discussed: behavior when the file exists but is malformed YAML, when it's an empty file, or when it's an array with no entries (MinerPool with zero miners — `query` would return an empty `PoolResult`). The "entry missing `host` key" case used to silently default to `CgminerApiClient.default_host` — that one is now handled and raises `CgminerApiClient::Error`.

### 7. `Miner#check_status` writes Info/Warning to stdout
`'I'` and `'W'` cgminer STATUS codes result in `puts "Info from API [..]: .."` / `puts "Warning..."`. That's library-code-writing-to-stdout, which slightly contradicts the "library never writes to stderr" posture stated in `architecture.md`. The claim is specifically about **stderr**; stdout for cgminer advisory messages is intended. Mentioned in `interfaces.md`, but the slight tension is worth flagging.

## Language and tooling limitations

- **Ruby-only.** No other languages are used. No FFI, no Rust extension, no native build step.
- **No CI for macOS or Windows** — GitHub Actions uses `ubuntu-24.04` only. The gem is pure Ruby and stdlib, so portability is likely fine, but it's not exercised.
- **No external service integration** to spec — the gem talks TCP to a cgminer instance. Integration is via `FakeCgminer`, which is tested-and-shipped-together but **not** automatically exercised against a real cgminer.
- **Documentation scope.** These docs cover the gem and its CLI. They do **not** cover how to operate cgminer itself. For that, see cgminer's own docs or the linked API-README.

## Recommendations

Low effort, high value:
1. Add a test that exercises `MinerPool` with zero miners in `config/miners.yml` (confirms the "empty PoolResult" behavior).

Higher effort, might not be worth it:
2. Decide whether the `}{` / `[,{` repair code paths should be kept (with a repro) or deleted (with a changelog note). A code comment now points to this decision, but the decision itself is still open.
3. Add a thread-safety section to the architecture docs if real-world users report the concurrent-query case.

## How I validated

- Read every file under `lib/`, `bin/`, `spec/support/`, and the top-level `config/`, `Gemfile`, `Gemfile.lock`, `.github/workflows/`, `.rubocop.yml`, `Rakefile`, `CHANGELOG.md`, `README.md`, `.rspec`, `.ruby-version`, and the gemspec.
- Did not read the unit specs' full bodies (only counted lines and spot-checked one). The behavioral claims in the docs are from the source files themselves, not derived from the spec assertions.
- Did not run the test suite as part of writing these docs. All claims about "tested" behavior are from reading the spec files' existence and inferred coverage, not from a pass/fail run.
