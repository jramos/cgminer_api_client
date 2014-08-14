# CgminerApiClient [![Build Status](https://travis-ci.org/jramos/cgminer_api_client.png?branch=master)](https://travis-ci.org/jramos/cgminer_api_client)

A gem that allows sending API commands to a pool of cgminer instances.

## Requirements

* Ruby (~> 2.0.0, ~> 2.1.0)
    * YAML
    * JSON
    * Socket
    * Thread
* cgminer (~> 3.12.0)

## Installation Options

### Bundler

Add the following to your ``Gemfile``:

    gem 'cgminer_api_client', '~> 0.1.12'

### RubyGems

    $ gem install cgminer_api_client

### Manually

    $ git clone git@github.com:jramos/cgminer_api_client.git

## Configuration

Copy [``config/miners.yml.example``](https://github.com/jramos/cgminer_api_client/blob/master/config/miners.yml.example) to ``config/miners.yml`` and update with the IP addresses (and optional ports) of your cgminer instances. E.g.:

    # connect to localhost on the default port (4028)
    - host: 127.0.0.1
    # connect to 192.168.1.1 on a non-standard port (1234)
    - host: 192.168.1.1
      port: 1234

### Remote API Access

Your cgminer instances must be configured to allow remote API access if connecting from anywhere but localhost (127.0.0.1). See the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README) for more information.

#### Linux Instructions

Under Linux, you would do the following to allow access from any computer on your local network (192.168.1.x):

    $ vi /etc/config/cgminer

Make the following change:

    # option api_allow 'W:127.0.0.1'
    option api_allow 'W:127.0.0.1,W:192.168.1.0/24'

You also need to updated the init.d script to pass the ``--api_allow`` option:

    $ vi /etc/init.d/cgminer

Make the following change:

    #PARAMS="$AOPTIONS $POOL1 $POOL2 $POOL3 $_pb --api-listen --api-network"
    PARAMS="$AOPTIONS $POOL1 $POOL2 $POOL3 $_pb --api-listen --api-network --api-allow $_aa"

Restart cgminer:

    $ /etc/init.d/cgminer restart

## Gem Usage

    require 'cgminer_api_client'
    
    pool = CgminerApiClient::MinerPool.new
    
    # run 'devs' on each miner in the pool; returns an array of response hashes
    devices = pool.devs
    
    # run 'summary' on each miner in the pool; returns an array of response hashes
    summaries = pool.summary
    
    # run commands on individual miners
    pool.miners.collect do |miner|
        miner.devs   # run 'devs' on this miner; returns a response hash
    end

### Commands

#### Read-Only

The following read-only miner and pool commands are currently available:

* asc(number)
* asccount
* check(command)
* coin
* config
* devdetails
* devs
* pga(number)
* pgacount
* pools
* privileged
* notify
* stats
* summary
* usbstats
* version

#### Privileged

The following privileged miner and pool commands are currently available:

##### Asc

* ascdisable(number)
* ascenable(number)
* ascidentify(number)
* ascset(number, option, value = nil)

##### Pga

* pgadisable(number)
* pgaenable(number)
* pgaidentify(number)
* pgaset(number, option, value = nil)

##### Pool

* addpool(url, user, pass)
* disablepool(number)
* enablepool(number)
* poolpriority(*id_order)
* poolquota(number, value)
* removepool(number)
* switchpool(number)

##### System

* debug(setting = 'D')
* failover_only(value)
* hotplug(seconds)
* quit
* restart
* save(filename = nil)
* setconfig(name, value)
* zero(which = 'All', full_summary = false)

Any cgminer API commands not explictly defined above are implemented using ``method_missing``. A complete list of available API commands and options can be found in the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README).

## CLI Usage

There is currently one command-line tool for viewing the overall status of your pool, ``bin/cgminer_pool_summary``.

    $ bin/cgminer_pool_summary 
    192.168.1.151:4028
    	GH/s(5s)	199.12
    	GH/s(avg)	200.98
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	330 min
    		Temp	51.0 C / 123.8 F
    		Rej	4.8539%
    		Err	0.3026%
    
    192.168.1.152:4028
    	GH/s(5s)	217.88
    	GH/s(avg)	201.05
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	324 min
    		Temp	48.5 C / 119.3 F
    		Rej	3.5152%
    		Err	0.315%
    
    192.168.1.153:4028
    	GH/s(5s)	192.82
    	GH/s(avg)	200.83
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	283 min
    		Temp	50.5 C / 122.9 F
    		Rej	3.3944%
    		Err	0.2986%
    
    192.168.1.154:4028
    	GH/s(5s)	196.22
    	GH/s(avg)	200.13
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	322 min
    		Temp	50.5 C / 122.9 F
    		Rej	5.2205%
    		Err	0.5668%
    
    192.168.1.155:4028
    	GH/s(5s)	201.97
    	GH/s(avg)	198.88
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	321 min
    		Temp	48.0 C / 118.4 F
    		Rej	5.6044%
    		Err	1.2791%
    
    192.168.1.156:4028
    	GH/s(5s)	215.7
    	GH/s(avg)	199.85
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	320 min
    		Temp	51.0 C / 123.8 F
    		Rej	4.6996%
    		Err	0.6069%
    
    =============================================
    
    Total GH/s
    	5s	1223.7 (204.0 / miner)
    	Avg	1201.7 (200.3 / miner)
    
    Error Rate
    	Avg	0.5615% / miner
    	GH/s(5s)	6.87
    	GH/s(avg)	6.75
    
    Temperature
    	Min	48.0 C / 118.4 F
    	Avg	49.9 C / 121.9 F
    	Max	51.0 C / 123.8 F

## GUI

* [https://github.com/jramos/cgminer_manager](https://github.com/jramos/cgminer_manager)

## Contributing

1. Fork it ( [https://github.com/jramos/cgminer\_api\_client/fork](https://github.com/jramos/cgminer_api_client/fork) )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Donating

If you find this gem useful, please consider donating.

BTC: ***REMOVED***

## License

Code released under [the MIT license](LICENSE.txt).