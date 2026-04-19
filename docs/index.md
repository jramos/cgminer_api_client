# Knowledge Base Index — `cgminer_api_client`

**This file is the entry point for AI assistants working on this gem.** It summarizes every other document in `docs/summary/` so an assistant can pull in only the file(s) relevant to a given question. When no single file is an obvious fit, read `AGENTS.md` (consolidated, at repo root) or skim `codebase_info.md` first.

## How to use this index

1. **Identify the question category** from the table below (Architecture? Public API? Error handling? Dev workflow?).
2. **Read the mapped file.** Each mapping includes a one-line "use this when" hook plus a brief summary.
3. **Cross-reference** via the explicit links between documents — they are maintained.
4. **Fall back** to reading the code. All docs are derived from `lib/` and `spec/`; if a doc and the code disagree, the code is truth and the doc is stale (report it).

## Question → file map

| If the question is about... | Start here |
|---|---|
| "what is this project?" / stack / directory layout / Ruby version / coverage | [`codebase_info.md`](codebase_info.md) |
| design patterns / mixin layout / why `method_missing` / why `Data.define` / CLI contract | [`architecture.md`](architecture.md) |
| what each class or module does / responsibilities / where to find X | [`components.md`](components.md) |
| public API shape / method signatures / CLI exit codes / `config/miners.yml` format / wire protocol | [`interfaces.md`](interfaces.md) |
| `MinerResult` / `PoolResult` invariants / error hierarchy / object graph | [`data_models.md`](data_models.md) |
| request flow / parallel pool fan-out / CLI execution / running tests / release process | [`workflows.md`](workflows.md) |
| gem deps / Ruby version support / CI matrix | [`dependencies.md`](dependencies.md) |
| known gaps, inconsistencies, caveats in the docs themselves | [`review_notes.md`](review_notes.md) |

## Document summaries

### [`codebase_info.md`](codebase_info.md)
**Purpose:** The one-pager. What the gem is, what Ruby versions it supports, what the file tree looks like, and which files are packaged in the gem vs. which are dev-only. Has a high-level module graph. **Start here if you've never seen the project.**

### [`architecture.md`](architecture.md)
**Purpose:** Why the code is shaped the way it is. Covers: the mixin-driven command surface (`Miner` and `MinerPool` both `include Miner::Commands`), `method_missing` fallback for uncommon cgminer commands, `Data.define` for `MinerResult`, the parallel-fan-out-with-capture-everything pattern, the dual error taxonomy (`ConnectionError` vs `ApiError`), the cgminer wire protocol that the gem speaks, and the single-miner-convenience-unwrap fix that `MinerPool` overrides for `summary`/`coin`/`config`/`version`/`check`. **Read this before making non-trivial code changes.**

### [`components.md`](components.md)
**Purpose:** Catalog of every file in `lib/` (and the two test-only helpers `FakeCgminer` + `CgminerFixtures`). Each entry lists the file path, primary responsibility, and key public methods. **Read this to find where a specific piece of behavior lives.**

### [`interfaces.md`](interfaces.md)
**Purpose:** Contract reference — exhaustive. Every public method on `Miner`, `MinerPool`, `MinerResult`, `PoolResult`. Every CLI command/exit-code/stream contract. The `config/miners.yml` schema. The upstream cgminer wire protocol (request/response envelope, STATUS codes). **Read this when asked about method signatures, CLI behavior, or wire format.**

### [`data_models.md`](data_models.md)
**Purpose:** Runtime value object graph. `MinerResult` and `PoolResult` methods, invariants, and pattern-match shape. Error class hierarchy. Raw vs. sanitized response shapes. **Read this for questions about "what comes back" or "what's in this object".**

### [`workflows.md`](workflows.md)
**Purpose:** Sequence diagrams and step-by-step flows. Single-miner request path (socket → response → parse → check_status → sanitize). Parallel pool query with `Thread`-per-miner fan-out and `MinerResult`-capture semantics. CLI invocation end-to-end. Development workflow (tests, integration with `FakeCgminer`, manual sandbox, RuboCop, release). **Read this to understand how code paths compose over time.**

### [`dependencies.md`](dependencies.md)
**Purpose:** Runtime (none; stdlib only) and dev deps with rationale. Resolved versions from `Gemfile.lock`. CI matrix. Ruby version rationale (why 3.2+). External cgminer dependency. **Read this for "can I add gem X?" or "what Rubies does this support?".**

### [`review_notes.md`](review_notes.md)
**Purpose:** Self-audit. Known inconsistencies, documentation gaps, and areas where the analysis couldn't reach definitive answers. **Read this when validating the rest of the docs, or before trusting a claim made elsewhere in `docs/summary/`.**

## Example queries and where to go

| Query | Primary file(s) |
|---|---|
| "How do I add a new cgminer command wrapper?" | `components.md` (see `Miner::Commands`), `architecture.md` (mixin pattern) |
| "Why doesn't `pool.summary` just return an array of hashes like in 0.2.x?" | `data_models.md` (PoolResult) + `architecture.md` (Single-miner convenience unwrap) + `CHANGELOG.md` |
| "What happens if a single miner is unreachable during `pool.restart`?" | `workflows.md` (Parallel pool request flow) + `data_models.md` (MinerResult failure shape) |
| "Can I run the CLI without real miners?" | `workflows.md` (Manual sandbox section) |
| "How is `connect_nonblock` with timeout implemented?" | `components.md` (`SocketWithTimeout`) + the source file itself |
| "What Ruby versions does this gem support and why?" | `dependencies.md` |
| "Where do cgminer's STATUS letters map to exception classes?" | `interfaces.md` (wire protocol) + `architecture.md` (dual error taxonomy) |
| "What's the CLI exit code when one of three miners fails?" | `interfaces.md` (CLI section) — partial success is exit 0 |

## Maintenance note

The docs in this directory were generated by analyzing the code directly. They reflect the state at gem version 0.3.0. When the code changes substantially:

- Prefer updating the specific file that contains the affected claim (smaller diffs, clearer history).
- Update `review_notes.md` if you find a new inconsistency or gap.
- Re-run the codebase-summary skill in `update_mode` if the surface area has shifted enough to warrant a re-analysis.

If you're an AI assistant and you find a doc that contradicts the current code, **trust the code** and flag the discrepancy to the human maintainer rather than silently fixing the doc.
