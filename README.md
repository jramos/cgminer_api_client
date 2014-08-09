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

    gem 'cgminer_api_client', '~> 0.1.10'

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

    vi /etc/init.d/cgminer

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
    	GH/s(5s)	191.24
    	GH/s(avg)	200.96
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	321 min
    		Temp	51.0 C
    		Err	0.3006%
    
    192.168.1.152:4028
    	GH/s(5s)	186.47
    	GH/s(avg)	201.08
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	315 min
    		Temp	48.5 C
    		Err	0.3129%
    
    192.168.1.153:4028
    	GH/s(5s)	206.14
    	GH/s(avg)	200.85
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	275 min
    		Temp	51.0 C
    		Err	0.2984%
    
    192.168.1.154:4028
    	GH/s(5s)	184.67
    	GH/s(avg)	200.19
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	313 min
    		Temp	50.5 C
    		Err	0.5673%
    
    192.168.1.155:4028
    	GH/s(5s)	174.07
    	GH/s(avg)	198.85
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	312 min
    		Temp	48.0 C
    		Err	1.2766%
    
    192.168.1.156:4028
    	GH/s(5s)	218.8
    	GH/s(avg)	199.87
    	Devices	1
    		Name	ANT
    		Status	Alive
    		Elapsed	311 min
    		Temp	51.0 C
    		Err	0.6057%
    
    =============================================
    
    Total GH/s
    	5s	1161.4 (193.6 / miner)
    	Avg	1201.8 (200.3 / miner)
    
    Error Rate
    	Avg	0.5603% / miner
    	GH/s(5s)	6.51
    	GH/s(avg)	6.73
    
    Temperature
    	Min	48.0 C
    	Avg	50.0 C
    	Max	51.0 C

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