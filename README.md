# CgminerApiClient [![Codacy Badge](https://api.codacy.com/project/badge/Grade/b59cb27aeae64f7c992f7072c5909788)](https://app.codacy.com/app/justin_28/cgminer_api_client?utm_source=github.com&utm_medium=referral&utm_content=jramos/cgminer_api_client&utm_campaign=Badge_Grade_Dashboard) [![Build Status](https://travis-ci.org/jramos/cgminer_api_client.png?branch=master)](https://travis-ci.org/jramos/cgminer_api_client) [![DepShield Badge](https://depshield.sonatype.org/badges/jramos/cgminer_api_client/depshield.svg)](https://depshield.github.io)

A gem that allows sending API commands to a pool of [cgminer](https://github.com/ckolivas/cgminer) instances.

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

    require 'cgminer_api_client'

    # change the default timeout and port for the miners
    CgminerApiClient.config do |config|
        config.default_port    = 4023
        config.default_timeout = 3
    end

    pool = CgminerApiClient::MinerPool.new

    # run 'devs' on each miner in the pool; returns an array of response hashes
    devices = pool.devs

    # run 'summary' on each miner in the pool; returns an array of response hashes
    summaries = pool.summary

    # run 'devs' on available miners; returns an array of response hashes
    pool.available_miners.collect do |miner|
        miner.devs
    end

    # restart the pool
    pool.restart

## CLI Usage

API commands can be sent to your miner pool from the command line.

    $ cgminer_api_client <command> (<arguments>)

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

## Contributing

1.  Fork it ( <https://github.com/jramos/cgminer_api_client/fork> )
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create a new Pull Request

## Donating

If you find this gem useful, please consider donating.

BTC: `18HFFqZv2KJMHPNwPes839PJd5GZc4cT3U`

## License

Code released under [the MIT license](LICENSE.txt).
