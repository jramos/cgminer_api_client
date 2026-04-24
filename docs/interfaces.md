# Interfaces

The gem exposes three public surfaces: the Ruby library, the `bin/cgminer_api_client` CLI, and the `config/miners.yml` file schema. Internally, it consumes the cgminer JSON-over-TCP API, which is documented briefly here for context on what the gem translates between.

## 1. Ruby library API

### Top-level module: `CgminerApiClient`

```ruby
require 'cgminer_api_client'

CgminerApiClient.default_host        # "127.0.0.1"
CgminerApiClient.default_port        # 4028
CgminerApiClient.default_timeout     # 5

CgminerApiClient.default_host = '192.168.1.1'
CgminerApiClient.default_port = 4028
CgminerApiClient.default_timeout = 3

CgminerApiClient.config do |c|
  c.default_port = 4028
  c.default_timeout = 3
end
```

`.config` simply yields `self` if given a block, so `CgminerApiClient.config { ... }` and `CgminerApiClient.default_port = 4028` are interchangeable.

### Single-miner client: `CgminerApiClient::Miner`

```ruby
miner = CgminerApiClient::Miner.new            # uses module defaults
miner = CgminerApiClient::Miner.new('10.0.0.5')
miner = CgminerApiClient::Miner.new('10.0.0.5', 4028)
miner = CgminerApiClient::Miner.new('10.0.0.5', 4028, 3)

# Optional on_wire callback for telemetry (see Logging section below)
miner = CgminerApiClient::Miner.new('10.0.0.5', on_wire: ->(dir, host, port, payload) {
  warn "#{dir} #{host}:#{port} #{payload}"
})

miner.host       # "10.0.0.5"
miner.port       # 4028
miner.timeout    # 3
```

Any of the three positional args can be omitted/nil; the corresponding `CgminerApiClient.default_*` value is used. `on_wire:` is optional; when omitted, no wire telemetry is emitted.

**Commands (all return the parsed, sanitized response on success; raise `ConnectionError` on transport failure, `ApiError` on cgminer rejection):**

```ruby
miner.summary                              # Hash
miner.stats                                # Array<Hash>
miner.pools                                # Array<Hash>
miner.devs                                 # Array<Hash>
miner.devdetails                           # Array<Hash>
miner.coin                                 # Hash
miner.config                               # Hash
miner.version                              # Hash
miner.check('summary')                     # Hash
miner.notify                               # Array<Hash>
miner.usbstats                             # Array<Hash>
miner.privileged                           # true | false (API denied)
miner.asc(0)                               # Array<Hash>
miner.asccount                             # Array<Hash>
miner.pga(0)                               # Array<Hash>
miner.pgacount                             # Array<Hash>

# Privileged (require privileged API access on the miner; raise if not)
miner.addpool(url, user, pass)
miner.removepool(number)
miner.switchpool(number)
miner.enablepool(number)
miner.disablepool(number)
miner.poolpriority(*id_order)
miner.poolquota(number, value)
miner.ascenable(number)
miner.ascdisable(number)
miner.ascidentify(number)
miner.ascset(number, option, value = nil)
miner.pgaenable(number)
miner.pgadisable(number)
miner.pgaidentify(number)
miner.pgaset(number, option, value = nil)
miner.restart
miner.quit
miner.save(filename = nil)
miner.setconfig(name, value)
miner.debug(setting = 'D')
miner.failover_only(value)
miner.hotplug(seconds)
miner.zero(which = 'All', full_summary = false)

# Any not-yet-wrapped command still works via method_missing:
miner.some_cgminer_command('a', 'b')

# Reachability probe (opens a fresh socket every call, no cache):
miner.available?                           # true | false

# Low-level escape hatch:
miner.query(:summary)                      # returns parsed Hash/Array
miner.query('summary+pools')               # multi-command syntax (keeps nested shape)
miner.query(:ascset, 0, 'freq', 650)       # positional params → comma-joined & escaped
```

**Key normalization:** cgminer response keys like `"MHS av"`, `"Found Blocks"`, `"Last Share Time"` are normalized to `:mhs_av`, `:found_blocks`, `:last_share_time` before being returned. Arrays and nested hashes are recursively processed.

**Pattern match for unknown commands:**

```ruby
miner.respond_to?(:summary)             # true  (real method)
miner.respond_to?(:some_weird_cmd)      # true  (via respond_to_missing?)
miner.respond_to?(:to_ary)              # false (to_* is carved out)
miner.respond_to?(:_dump)               # false (_* is carved out)
```

### Pool client: `CgminerApiClient::MinerPool`

```ruby
pool = CgminerApiClient::MinerPool.new       # reads ./config/miners.yml
pool = CgminerApiClient::MinerPool.new(on_wire: my_callback)  # telemetry hook
pool.miners                                  # Array<Miner> in config order
pool.reload_miners!                          # re-read config/miners.yml
```

`MinerPool.new` accepts a single `on_wire:` keyword arg; the same callback is forwarded into each `Miner` it constructs, so every per-miner request/response fires through one hook. See the Logging section below.

**Commands (same surface as `Miner`; all return a `PoolResult` of `MinerResult`s):**

```ruby
pool.summary                                 # PoolResult (successful values are Hashes)
pool.stats                                   # PoolResult (successful values are Arrays)
pool.restart                                 # PoolResult
pool.addpool(url, user, pass)                # PoolResult
# ... etc, every Miner command works on a pool.

# Reachability:
pool.available_miners                        # Array<Miner> (reachable subset, in pool order)
pool.unavailable_miners                      # Array<Miner> (unreachable subset)

# Low-level:
pool.query(:summary)                         # PoolResult
```

**Consuming a `PoolResult`:**

```ruby
result = pool.summary

# Success-only projections
result.values            # [Hash, Hash, ...]       — successful values only
result.successful        # [MinerResult, ...]      — ok? == true
result.failed            # [MinerResult, ...]      — failed? == true
result.errors            # [<ConnectionError>, ...]

# Predicates
result.all_successful?   # true if every miner ok
result.any_succeeded?    # true if ≥1 miner ok
result.any_failed?       # true if ≥1 miner failed

# Lookup
result[0]                        # by index
result[miner_instance]           # by Miner instance
result['10.0.0.5:4028']          # by "host:port" string

# Iterate per-miner (default)
result.each do |r|
  if r.ok?
    puts "#{r.miner.host}: #{r.value[:mhs_av]}"
  else
    warn "#{r.miner.host}: #{r.error.class}: #{r.error.message}"
  end
end
```

### `MinerResult` and `PoolResult`

Both are loaded automatically by `require 'cgminer_api_client'`. See [data_models.md](data_models.md) for the full shape.

### Error classes

```ruby
CgminerApiClient::Error             # < StandardError
CgminerApiClient::ConnectionError   # < Error (transport-level)
CgminerApiClient::TimeoutError      # < ConnectionError (connect timeout specifically)
CgminerApiClient::ApiError          # < Error (cgminer STATUS=E or F)
```

Rescue hierarchy: `rescue CgminerApiClient::Error` catches everything gem-specific. `rescue CgminerApiClient::ConnectionError` catches both `TimeoutError` and other transport failures. `rescue CgminerApiClient::TimeoutError` catches *only* connect timeouts. All still descend from `StandardError` so existing blanket rescues keep working.

## 2. CLI interface

### Binary

```
cgminer_api_client <command> [<arguments>]
```

Invocation happens from a directory containing `config/miners.yml`. The CLI reads that file to build its `MinerPool`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | at least one miner's query succeeded |
| 1 | every miner failed, OR a top-level exception bubbled up |
| 64 | `EX_USAGE` — unknown command or missing command argument |

### stdout vs stderr

| Stream | Contents |
|---|---|
| stdout | per-miner `host:port:` header lines, followed by the `pp`-formatted response value |
| stderr | per-miner `host:port: ErrorClass: message` lines for failed miners; `USAGE:` and top-level error messages |

Library code never writes to stderr. The CLI owns that channel. Existing shell pipelines capturing stdout get clean output even when some miners fail.

### Flags

| Flag | Purpose |
|---|---|
| `-v` / `--verbose` | Print each outbound request (JSON) and inbound response (raw string, pre-parse) to stderr prefixed with direction (`>>>`, `<<<`, or `<<< (repaired)` for the legacy `}{`-repair path) and `host:port`. Operator-facing diagnostic output, not a parse-able contract. Writes are mutex-serialized so interleaved per-miner lines don't tear. |

Place the flag before the command: `cgminer_api_client -v summary`.

### Environment variables

- `DEBUG=1` — on a top-level (unhandled) exception, also print the full backtrace via `Exception#full_message(highlight: false)` to stderr.

### Examples

```sh
$ cgminer_api_client summary
10.0.0.1:4028:
{:elapsed=>12345, :mhs_av=>56789.12, :found_blocks=>0, ...}
10.0.0.2:4028:
{:elapsed=>5432, :mhs_av=>56780.00, :found_blocks=>0, ...}

$ cgminer_api_client restart
10.0.0.1:4028:
{...}
10.0.0.2:4028: CgminerApiClient::ConnectionError: Connection to 10.0.0.2:4028 failed: Errno::ECONNREFUSED: Connection refused
# exit code 0 (at least one succeeded)

$ cgminer_api_client bogus_command
USAGE: cgminer_api_client command (arguments)
commands: addpool, asc, asccount, ascdisable, ...
Set DEBUG=1 to see full backtraces on errors.
# exit code 64

$ DEBUG=1 cgminer_api_client summary
# ... same output plus full backtrace on any unhandled exception
```

### Logging and telemetry

The CLI is the only surface that writes diagnostic lines to stderr; the library is silent by design. See [`docs/logging.md`](logging.md) for the full posture, the event names sibling gems (`cgminer_monitor`, `cgminer_manager`) use when they log api_client outcomes, and how the `on_wire:` library hook compares to the CLI's `-v` flag (same mechanism — the CLI installs a default `on_wire` that writes to stderr).

## 3. `config/miners.yml` schema

Path: `./config/miners.yml` (relative to process CWD).

YAML array of mappings. Each mapping:

| Key | Required | Type | Default |
|---|---|---|---|
| `host` | yes | string (IP or hostname) | — |
| `port` | no | integer | `CgminerApiClient.default_port` (4028) |
| `timeout` | no | integer (seconds) | `CgminerApiClient.default_timeout` (5) |

Parsed with `YAML.safe_load_file` — no custom types, symbols, or procs.

Example:

```yaml
- host: 127.0.0.1                  # uses default port 4028, default timeout 5s
- host: 192.168.1.1                # custom port and timeout
  port: 1234
  timeout: 3
- host: miner3.example.com         # DNS works
```

The example file at `config/miners.yml.example` is packaged with the gem; `config/miners.yml` is `.gitignore`d.

## 4. Upstream wire protocol (consumed by the gem, not exposed)

The gem talks to cgminer's JSON API. This is documented at [cgminer's API-README](https://github.com/ckolivas/cgminer/blob/master/API-README) and summarized here so future changes to the gem have context.

### Transport
- TCP, default port 4028, IPv4.
- Client writes one JSON request, reads until EOF, server closes connection.

### Request shape
```json
{"command":"summary"}
{"command":"ascset","parameter":"0,freq,650"}
```

### Response shape
Single JSON object. Universal envelope:
```json
{
  "STATUS": [{
    "STATUS": "S",               // S/I/W/E/F — see table below
    "When":   1700000000,
    "Code":   11,                 // cgminer MSG code
    "Msg":    "Summary",
    "Description": "cgminer 4.11.1"
  }],
  "SUMMARY": [...],               // command-specific key(s); varies per command
  "id": 1
}
```

STATUS codes (as interpreted by `Miner#check_status`):

| Letter | Meaning | Gem behavior |
|---|---|---|
| `S` | Success | silent |
| `I` | Info | `puts` to stdout |
| `W` | Warning | `puts` to stdout |
| `E` | Error | raises `ApiError` |
| `F` | Fatal | raises `ApiError` |

### Quirks the gem handles
1. **Control bytes in string values** (pool names, worker IDs can contain raw 0x01–0x1F). Re-escaped as `\uXXXX` before `JSON.parse`.
2. **Malformed multi-object responses** of the form `}{` between sibling objects. Legacy repair replaces with `}, {`. May no longer fire on modern cgminer.
3. **Single-element array responses** for `summary`/`coin`/`config`/`version`/`check`. Unwrapped by `Miner::Commands::ReadOnly`.
4. **Multi-command syntax** (`summary+pools`). Response is a top-level object with one sub-key per subcommand; each sub-value is an array whose first element has its own STATUS block. Detected by `+` in the command name; gem calls `check_status` per sub-response.
