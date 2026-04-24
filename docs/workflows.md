# Workflows

Three request flows cover essentially everything the gem does: single-miner query, parallel pool query, and CLI invocation. Plus two dev/test workflows: running the suite against a fake cgminer, and a manual sandbox loop.

## 1. Single-miner request flow (`Miner#query`)

```mermaid
sequenceDiagram
    participant Caller
    participant Miner
    participant SWT as SocketWithTimeout
    participant cgminer

    Caller->>Miner: miner.summary
    Note over Miner: ReadOnly#summary → query(:summary)[0]
    Miner->>Miner: build {command: :summary} (add :parameter if params)
    Miner->>SWT: open_socket(host, port, timeout)
    alt connect OK
        SWT-->>Miner: Socket
    else connect timeout
        SWT--xMiner: TimeoutError
        Miner--xCaller: ConnectionError (re-wrapped)
    else other connect failure
        SWT--xMiner: SocketError / SystemCallError
        Miner--xCaller: ConnectionError (re-wrapped)
    end
    Miner->>Miner: safe_on_wire(:request, request.to_json) — fires on_wire: if set
    Miner->>cgminer: write(request.to_json)
    cgminer-->>Miner: JSON response + EOF
    Miner->>Miner: safe_on_wire(:response, raw_response) — fires on_wire: if set
    Miner->>Miner: re-escape control bytes < 0x20
    Miner->>Miner: gsub repairs for '}{' & '[,{'
    opt '}{' repair ran
        Miner->>Miner: safe_on_wire(:response_repaired, repaired)
    end
    Miner->>Miner: JSON.parse(response)
    Miner->>Miner: check_status(data) — raise ApiError on E/F
    Miner->>Miner: sanitized(data) — keys lowercased + symbolized
    Miner-->>Caller: data[:summary] — or full hash for multi-command
```

**Key observations:**
- No retries, ever. Caller decides whether to retry.
- No connection reuse. Every call opens and closes a fresh socket.
- Read-to-EOF pattern. Server closing the socket is what signals "response complete."
- `Miner#query` only raises `ConnectionError` or `ApiError` (or a bug like `ArgumentError` if misused); cgminer `STATUS=I`/`STATUS=W` just print a line and continue.
- `safe_on_wire` is a no-op when `on_wire:` wasn't passed to `Miner.new`; when it was, any exception the callback raises is swallowed so a buggy logger can't break a query. See `docs/logging.md` for the full posture and the CLI's `-v`/`--verbose` flag, which is implemented by installing a default `on_wire` callback.

## 2. Parallel pool request flow (`MinerPool#query`)

```mermaid
sequenceDiagram
    participant Caller
    participant MinerPool
    participant Thread_A as Thread #0
    participant Thread_B as Thread #1
    participant Thread_N as Thread #N
    participant Miner_A as Miner #0
    participant Miner_B as Miner #1
    participant Miner_N as Miner #N
    participant PoolResult

    Caller->>MinerPool: pool.summary
    Note over MinerPool: summary = unwrap_first(query(:summary))
    MinerPool->>Thread_A: Thread.new { Miner_A.query(:summary) }
    MinerPool->>Thread_B: Thread.new { Miner_B.query(:summary) }
    MinerPool->>Thread_N: Thread.new { Miner_N.query(:summary) }

    par Miner #0
        Thread_A->>Miner_A: miner.query(:summary)
        alt success
            Miner_A-->>Thread_A: [hash]
            Thread_A-->>Thread_A: MinerResult.success(miner, [hash])
        else transport / api failure
            Miner_A--xThread_A: ConnectionError / ApiError
            Thread_A-->>Thread_A: MinerResult.failure(miner, e)
        end
    and Miner #1
        Thread_B->>Miner_B: miner.query(:summary)
        Miner_B-->>Thread_B: result
    and Miner #N
        Thread_N->>Miner_N: miner.query(:summary)
        Miner_N-->>Thread_N: result
    end

    MinerPool->>MinerPool: threads.each(&:join)
    MinerPool->>MinerPool: threads.map(&:value) — in original pool order
    MinerPool->>PoolResult: new(results)
    MinerPool->>MinerPool: unwrap_first(pool_result) for summary/coin/config/version/check
    MinerPool-->>Caller: PoolResult
```

**Key observations:**
- Each miner runs in its own `Thread`. True concurrency for I/O since `open_socket`, `socket.wait_writable`, `s.read` all release the GVL.
- Thread-local `rescue StandardError => e` turns **any** failure into a `MinerResult.failure`. The caller's pool query never itself raises a per-miner error (barring a bug outside the rescue, in which case `Thread#value` re-raises to the caller).
- `threads.map(&:value)` preserves pool order because the threads array preserves iteration order.
- `unwrap_first` is the final step for the five ReadOnly convenience methods (`summary`, `coin`, `config`, `version`, `check`). It walks the `PoolResult`, replacing each successful `MinerResult.value` with `value.first`. Failures pass through untouched.

## 3. CLI invocation flow (`bin/cgminer_api_client`)

```mermaid
flowchart TD
    A[user runs cgminer_api_client CMD ARGS] --> B{command given?}
    B -- no --> Usage1[print USAGE to stderr<br/>exit 64]
    B -- yes --> C{command ∈ Miner::Commands.instance_methods?}
    C -- no --> Usage1
    C -- yes --> D[CgminerApiClient::MinerPool.new]
    D -->|reads config/miners.yml| E[pool.query command, *ARGS]
    E --> F[iterate PoolResult]
    F --> G{result.ok?}
    G -- yes --> H["puts 'host:port:' header, pp r.value"]
    G -- no --> I["warn 'host:port: ErrClass: message' to stderr"]
    H --> J{more results?}
    I --> J
    J -- yes --> F
    J -- no --> K{any miner succeeded?}
    K -- yes --> L[exit 0]
    K -- no --> M[exit 1]

    %% Top-level rescue
    D -.any StandardError.-> N["warn CLI-level error to stderr;<br/>full_message if DEBUG=1;<br/>exit 1"]
    E -.any StandardError.-> N
```

**Key observations:**
- The CLI is the only code path that writes to stderr. Library code never does.
- Command validation is against `Miner::Commands.instance_methods`, which means every real cgminer command wrapped by `ReadOnly`/`Privileged` modules is callable from CLI. Unwrapped commands (those only reachable via `method_missing`) are not callable from CLI — this is by design.
- Top-level exceptions (e.g. `"Please create config/miners.yml"`) land in the outer `rescue StandardError` and produce exit 1 with the error on stderr.
- `DEBUG=1` enables full backtraces via `Exception#full_message(highlight: false)`. Without it, only the error class and message are shown.
- Partial success is explicitly a success (exit 0). Fleet-oriented tooling pattern — partial failures don't trigger alerts.

## 4. Development workflow

### Running tests

```sh
bundle install
bundle exec rspec                      # unit + integration
bundle exec rspec spec/cgminer_api_client  # unit only
bundle exec rspec spec/integration     # integration only
bundle exec rake                       # spec + rubocop (the default task)
```

**Coverage** is enabled automatically via SimpleCov (see `spec/spec_helper.rb`). Reports land in `coverage/`.

**RSpec config** (`.rspec`): `--color --warnings --require spec_helper`. Warnings are deliberately on — the suite is expected to run warning-clean.

### Integration tests

`spec/integration/miner_integration_spec.rb` exercises the full `Miner` request path against `FakeCgminer` running in a background thread in the same process. `spec/integration/cli_spec.rb` uses `Open3.capture3` to spawn the real `bin/cgminer_api_client` and assert on exit codes and stdout/stderr split.

```mermaid
sequenceDiagram
    participant Spec
    participant FakeCgminer
    participant Miner

    Spec->>FakeCgminer: FakeCgminer.with { |port| ... }
    FakeCgminer->>FakeCgminer: TCPServer on 127.0.0.1:ephemeral
    FakeCgminer->>FakeCgminer: Thread.new { accept_loop }
    Spec->>Miner: Miner.new('127.0.0.1', port)
    Spec->>Miner: miner.summary
    Miner->>FakeCgminer: TCP connect + write request
    FakeCgminer->>FakeCgminer: JSON.parse(request)
    FakeCgminer->>FakeCgminer: lookup canned response
    FakeCgminer-->>Miner: write response + close
    Miner-->>Spec: parsed hash
    Spec->>Spec: assertions
    Note over Spec,FakeCgminer: on block exit:<br/>server.close, thread.join
```

### Manual sandbox (`script/fake_cgminer`)

Same `FakeCgminer` server, but foreground and long-running. Useful for exercising the CLI end-to-end without real mining hardware.

```sh
# terminal 1
./script/fake_cgminer 4028
# → fake cgminer listening on 127.0.0.1:4028
# → commands available: addpool, devs, pools, privileged, summary, summary+pools

# terminal 2
cp config/miners.yml.example config/miners.yml   # points at 127.0.0.1:4028
bundle exec bin/cgminer_api_client summary
# ... inspect output, iterate
```

### Linting

```sh
bundle exec rubocop                    # check
bundle exec rubocop -A                 # auto-correct (with caution)
```

`.rubocop.yml` turns off most `Metrics/*` cops (the gem is small and the defaults fight it without adding value) and the `RSpec/*` style cops (the existing suite uses idiomatic-for-its-time patterns). Correctness cops (`RSpec/RepeatedExample`, `RSpec/LeakyConstantDeclaration`, etc.) are deliberately left on — don't disable them without a specific reason.

## 5. Release / publish flow

Not automated. Manual process on a clean `master`:

```sh
bundle exec rake                                 # must pass
gem build cgminer_api_client.gemspec             # produces cgminer_api_client-X.Y.Z.gem
gem push cgminer_api_client-X.Y.Z.gem            # requires 2FA because rubygems_mfa_required
git tag vX.Y.Z
git push origin master vX.Y.Z
```

A `cgminer_api_client-0.3.0.gem` artifact is currently present at the repo root (untracked) from the 0.3.0 release.
