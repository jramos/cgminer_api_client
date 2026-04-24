# Logging

`cgminer_api_client` is **silent by design.** It has no `Logger` module and emits no structured log events. On failure `Miner#query` raises from the public hierarchy in `lib/cgminer_api_client/errors.rb` — `CgminerApiClient::Error`, `ConnectionError` (transport-layer), `TimeoutError < ConnectionError` (connect timeout specifically), `ApiError` (cgminer `STATUS=E`/`F` response). `MinerPool#query` captures these into `MinerResult.failure` rather than raising, so a pool call always returns a `PoolResult` even when every miner fails.

Callers — `cgminer_monitor`'s poll loop, `cgminer_manager`'s fleet commander, the `bin/cgminer_api_client` CLI — own the log call sites and decide what's worth emitting. This keeps the library dependency-free of any logging backend and lets each consumer pick its own verbosity / destination / format.

## Library-level hook: `on_wire:`

Both `Miner.new` and `MinerPool.new` accept an optional `on_wire:` keyword arg — a `proc.(direction, host, port, payload)` invoked for each request / response / `}{`-repaired response. `MinerPool` forwards the same callback into every `Miner` it constructs so a single hook covers the whole fan-out. The callback is wrapped in `safe_on_wire` — any exception it raises is swallowed with no retry, so a buggy logger cannot break a query.

Directions:
- `:request` — outbound JSON just before `socket.write`.
- `:response` — raw inbound string, pre-parse.
- `:response_repaired` — the rare legacy path where cgminer returned `}{`-concatenated JSON and the client split it; carries the repaired string.

## CLI: `-v`/`--verbose`

The CLI has a `-v`/`--verbose` flag that installs a default `on_wire` writing each direction to stderr with a direction prefix (`>>>`, `<<<`, `<<< (repaired)`) and `host:port`. Writes are mutex-serialized to keep interleaved per-miner lines intact. Handles `Errno::EPIPE` / `IOError` defensively — if stderr closes mid-run (because a downstream `| head` exited), the query fan-out keeps going. This is operator-facing diagnostic output, not a structured-log contract — the lines are not JSON and are not intended to be parsed. Use it to debug a specific miner interactively; don't pipe it into an aggregator.

## How callers log api_client outcomes

Both sibling gems follow the structured-log contract documented in `cgminer_monitor`:

→ **[cgminer_monitor/docs/log_schema.md](https://github.com/jramos/cgminer_monitor/blob/develop/docs/log_schema.md)**

The events of interest for api_client-outcome tracing:

- `poll.miner_failed` (cgminer_monitor) — emitted when `CgminerApiClient::MinerPool#query` raises for a specific miner. Carries `miner`, `command`, `error`.
- `poll.unexpected_error` (cgminer_monitor) — emitted when the poll loop itself catches something unexpected. Carries `error`, `message`, `backtrace`.
- `monitor.call` / `monitor.call.failed` (cgminer_manager) — *manager's* outbound HTTP calls to monitor, not api_client calls. Separate path.

The exception class names that surface in those events (`error:` key) are api_client's public error hierarchy in `lib/cgminer_api_client/errors.rb`.
