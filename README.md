# CgminerApiClient

[![CI](https://github.com/jramos/cgminer_api_client/actions/workflows/ci.yml/badge.svg)](https://github.com/jramos/cgminer_api_client/actions/workflows/ci.yml)

A gem that allows sending API commands to a pool of [cgminer](https://github.com/ckolivas/cgminer) instances. Ships as both a Ruby library and a CLI (`cgminer_api_client <command>`). Zero runtime dependencies beyond the Ruby standard library.

## Requirements

Ruby 3.2 or higher.

## Installation Options

### RubyGems

    $ gem install cgminer_api_client

### Manually

    $ git clone git@github.com:jramos/cgminer_api_client.git
    $ cd cgminer_api_client
    $ gem build cgminer_api_client.gemspec
    $ gem install cgminer_api_client-<VERSION>.gem

## Configuration

Copy [`config/miners.yml.example`](https://github.com/jramos/cgminer_api_client/blob/master/config/miners.yml.example) to `config/miners.yml` and update with the IP addresses (and optional ports and timeouts) of your cgminer instances. E.g.:

    # connect to localhost on default port (4028) with default timeout (5 seconds)
    - host: 127.0.0.1
    # connect to 192.168.1.1 on port (1234) with custom timeout (3 seconds)
    - host: 192.168.1.1
      port: 1234
      timeout: 3

### Remote API Access

Your cgminer instances must be configured to allow remote API access if connecting from anywhere but localhost (127.0.0.1). See the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README) for more information.

#### Linux Instructions

Under Linux, you would do the following to allow access from any computer on your local network (192.168.1.x):

    $ vi /etc/config/cgminer

Make the following change:

    # option api_allow 'W:127.0.0.1'
    option api_allow 'W:127.0.0.1,W:192.168.1.0/24'

You also need to updated the init.d script to pass the `--api_allow` option:

    $ vi /etc/init.d/cgminer

Make the following change:

    #PARAMS="$AOPTIONS $POOL1 $POOL2 $POOL3 $_pb --api-listen --api-network"
    PARAMS="$AOPTIONS $POOL1 $POOL2 $POOL3 $_pb --api-listen --api-network --api-allow $_aa"

Restart cgminer:

    $ /etc/init.d/cgminer restart

## Gem Usage

```ruby
require 'cgminer_api_client'

# Change the defaults for any miners whose config doesn't set them.
CgminerApiClient.config do |config|
  config.default_port    = 4028
  config.default_timeout = 3
end

pool = CgminerApiClient::MinerPool.new
```

### Pool queries return a `PoolResult`

Every pool query returns a `PoolResult` — an `Enumerable` wrapper
around one `MinerResult` per miner, in pool order. Each
`MinerResult` is either a success (carrying a parsed value) or a
failure (carrying the exception). Callers choose how much detail
they care about.

```ruby
# Just give me the data, ignore failures:
pool.summary.values.each do |s|
  puts "hashrate: #{s[:mhs_av]}"
end

# Handle successes and failures explicitly:
pool.summary.each do |result|
  if result.ok?
    puts "#{result.miner.host}: #{result.value[:mhs_av]}"
  else
    warn "#{result.miner.host}: #{result.error.message}"
  end
end

# Quick checks:
pool.summary.all_successful?   # true if every miner responded
pool.summary.any_failed?       # true if any miner failed
pool.summary.errors            # [<ConnectionError>, ...]
pool.summary['10.0.0.5:4028']  # lookup by host:port string
```

### Single-miner access

If you want to talk to one specific miner without the pool
wrapping, use `Miner` directly. Unreachable miners raise
`CgminerApiClient::ConnectionError`:

```ruby
miner = CgminerApiClient::Miner.new('10.0.0.5', 4028)
begin
  puts miner.summary[:mhs_av]
rescue CgminerApiClient::ConnectionError => e
  warn "miner unreachable: #{e.message}"
end
```

### Privileged commands

Commands like `restart`, `quit`, `save`, `addpool`, `removepool`,
`ascset`, etc. require privileged API access on the cgminer side.
They propagate `CgminerApiClient::ApiError` on rejection and
`CgminerApiClient::ConnectionError` on network failure — two
distinct conditions, unlike in 0.2.x where they were conflated.

```ruby
pool.restart      # PoolResult of per-miner outcomes
```

### Errors

All gem-specific errors descend from `CgminerApiClient::Error < StandardError`:

-   `CgminerApiClient::ConnectionError` — transport-level: the miner
    was unreachable (DNS failure, connection refused, etc.).
-   `CgminerApiClient::TimeoutError` — a `ConnectionError` subclass
    for connect timeouts specifically.
-   `CgminerApiClient::ApiError` — protocol-level: the miner answered
    and returned a `STATUS=E`/`F` response.

`rescue CgminerApiClient::Error` catches everything gem-specific.
`rescue CgminerApiClient::ConnectionError` catches both generic
transport failures and connect timeouts. A `MinerPool` query never
raises per-miner errors — they land on the corresponding
`MinerResult.failure` inside the returned `PoolResult`.

## CLI Usage

API commands can be sent to your miner pool from the command line.

    $ cgminer_api_client <command> (<arguments>)

### Exit Codes and Streams

-   exit `0` — at least one miner's command succeeded.
-   exit `1` — every miner failed, or a top-level exception bubbled up.
-   exit `64` — unknown command or missing command argument (`EX_USAGE`).

Per-miner responses are printed to stdout with a `host:port:` header.
Per-miner errors are printed to stderr as
`host:port: ErrorClass: message`. Set `DEBUG=1` to also print full
backtraces for any top-level exception:

    $ DEBUG=1 cgminer_api_client summary

Pass `-v` / `--verbose` to log the JSON request and raw response to
stderr for wire-level debugging. Each line carries a `host:port`
prefix so fan-out across multiple miners stays grep-able:

    $ cgminer_api_client -v summary
    >>> 10.0.0.1:4028 {"command":"summary"}
    <<< 10.0.0.1:4028 {"STATUS":[{"STATUS":"S",...}],"SUMMARY":[...]}

Password-bearing arguments to `addpool`, `setconfig`, `ascset`, and
`pgaset` are replaced with `[REDACTED]` in the log output (the real
value is still sent on the wire).

### Commands & Arguments

#### Read-Only

The following read-only miner and pool commands are currently available:

-   asc(number)
-   asccount
-   check(command)
-   coin
-   config
-   devdetails
-   devs
-   pga(number)
-   pgacount
-   pools
-   privileged
-   notify
-   stats
-   summary
-   usbstats
-   version

#### Privileged

The following privileged miner and pool commands are currently available:

##### Asc

-   ascdisable(number)
-   ascenable(number)
-   ascidentify(number)
-   ascset(number, option, value = nil)

##### Pga

-   pgadisable(number)
-   pgaenable(number)
-   pgaidentify(number)
-   pgaset(number, option, value = nil)

##### Pool

-   addpool(url, user, pass)
-   disablepool(number)
-   enablepool(number)
-   poolpriority(\*id_order)
-   poolquota(number, value)
-   removepool(number)
-   switchpool(number)

##### System

-   debug(setting = 'D')
-   failover_only(value)
-   hotplug(seconds)
-   quit
-   restart
-   save(filename = nil)
-   setconfig(name, value)
-   zero(which = 'All', full_summary = false)

Any cgminer API commands not explictly defined above are implemented using `method_missing`. A complete list of available API commands and options can be found in the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README).

## Further Reading

-   [`CHANGELOG.md`](CHANGELOG.md) — release history and the 0.2.x → 0.3.0 migration guide.
-   [`AGENTS.md`](AGENTS.md) — context for AI coding assistants; also a useful conventions-and-extension guide for human contributors.
-   [`docs/`](docs/) — topic-split deep dives on architecture, components, interfaces, data models, workflows, and dependencies. Start with [`docs/index.md`](docs/index.md).
-   [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README) — upstream documentation for the JSON API surface this gem wraps.

## Contributing

1.  Fork it ( <https://github.com/jramos/cgminer_api_client/fork> )
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create a new Pull Request

## Donating

If you find this gem useful, please consider donating.

BTC: `bc1q00genlpcpcglgd4rezqcurf4t4taz0acmm9vea`

## License

Code released under [the MIT license](LICENSE.txt).
