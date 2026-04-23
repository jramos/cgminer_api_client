# Logging

`cgminer_api_client` is **silent by design.** It has no `Logger` module and emits no structured log events. On failure it raises (`CgminerApiClient::ConnectionError`, `CgminerApiClient::SocketReadTimeout`, `CgminerApiClient::ProtocolError`, etc.); on success it returns `CgminerApiClient::MinerResult` or `CgminerApiClient::PoolResult` instances.

Callers — `cgminer_monitor`'s poll loop, `cgminer_manager`'s fleet commander, the `bin/cgminer_api_client` CLI — own the log call sites and decide what's worth emitting. This keeps the library dependency-free of any logging backend and lets each consumer pick its own verbosity / destination / format.

The CLI has a `-v`/`--verbose` flag that prints each request and response to stderr with a direction prefix + `host:port`. This is operator-facing diagnostic output, not a structured-log contract — the lines are not JSON and are not intended to be parsed. Use it to debug a specific miner interactively; don't pipe it into an aggregator.

## How callers log api_client outcomes

Both sibling gems follow the structured-log contract documented in `cgminer_monitor`:

→ **[cgminer_monitor/docs/log_schema.md](https://github.com/jramos/cgminer_monitor/blob/develop/docs/log_schema.md)**

The events of interest for api_client-outcome tracing:

- `poll.miner_failed` (cgminer_monitor) — emitted when `CgminerApiClient::MinerPool#query` raises for a specific miner. Carries `miner`, `command`, `error`.
- `poll.unexpected_error` (cgminer_monitor) — emitted when the poll loop itself catches something unexpected. Carries `error`, `message`, `backtrace`.
- `monitor.call` / `monitor.call.failed` (cgminer_manager) — *manager's* outbound HTTP calls to monitor, not api_client calls. Separate path.

The exception class names that surface in those events (`error:` key) are api_client's public error hierarchy in `lib/cgminer_api_client/errors.rb`.
