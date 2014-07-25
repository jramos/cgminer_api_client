# CgminerApiClient [![Build Status](https://travis-ci.org/jramos/cgminer_api_client.png?branch=master)](https://travis-ci.org/jramos/cgminer_api_client)

A gem that allows sending API commands to a pool of cgminer instances.

## Requirements

* Ruby (1.9.3+)
* YAML
* JSON
* Socket

## Installation

Clone this repository.

## Configuration

Copy ``config/miners.yml.example`` to ``config/miners.yml`` and update with the IP addresses (and optional ports) of your cgminer instances. E.g.

    # connect to localhost on the default port (4028)
    - host: 127.0.0.1
    # connect to 192.168.1.1 on a non-standard port (1234)
    - host: 192.168.1.1
      port: 1234

### Remote API Access

Your cgminer instances must be configured to allow remote API access if connecting to anywhere but localhost (127.0.0.1). See the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README) for more information.

#### AntMiner S1 Instructions
On an [AntMiner S1](https://www.bitmaintech.com/productDetail.htm?pid=00020140107162747992Ce5uBuxW06D6), you would do the following to allow access from your local network (192.168.1.x).

    $ ssh -l root <antminer-ip>
    root@<antminer-ip>'s password: root
    
    BusyBox v1.19.4 (2013-12-25 11:50:48 CST) built-in shell (ash)
    Enter 'help' for a list of built-in commands.
    
      _______                     ________        __
     |       |.-----.-----.-----.|  |  |  |.----.|  |_
     |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
     |_______||   __|_____|__|__||________||__|  |____|
              |__| W I R E L E S S   F R E E D O M
     ...
     
    root@antMiner:~# vi /etc/config/cgminer

Make the following change:

    # option api_allow 'W:127.0.0.1'
    option api_allow 'W:127.0.0.1,W:192.168.1/24'

Restart cgminer:

    /etc/init.d/cgminer restart

## CLI Usage

There is currently one command-line tool for viewing the overall status of your pool.

    $ bin/pool_summary
    192.168.1.1:4028
    	GH/s	178.53
    	Devices	1
    		Name	BMM
    		Status	Alive
    		Elapsed	261 min
    		Temp	47.0 C
    		Err	    0.1993%
    
    192.168.1.2:4028
    	GH/s	191.58
    	Devices	1
    		Name	BMM
    		Status	Alive
    		Elapsed	1394 min
    		Temp	48.0 C
    		Err	    0.0009%
    
    192.168.1.3:4028
    	GH/s	191.55
    	Devices	1
    		Name	BMM
    		Status	Alive
    		Elapsed	1391 min
    		Temp	48.0 C
    		Err	    0.0714%
    
    Total GH/s: 561.66 (187.2 avg/miner)

## Gem Usage

    require 'cgminer_api_client'
    
    pool = CgminerApiClient::Pool.new
    
    # run 'devs' on each miner in the pool; returns an array of response hashes
    devices = pool.devs
    
    # run 'summary' on each miner in the pool; returns an array of response hashes
    summaries = pool.summary
    
    # run commands on individual miners
    pool.miners.collect do |miner|
        miner.devs   # run 'devs' on this miner; returns a response hash
    end

Any commands not explictly defined are implemented using ``method_missing``. A complete list of available API commands can be found in the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README).

## Contributing

1. Fork it ( https://github.com/jramos/cgminer_api_client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Donating

If you find this gem useful, please consider donating.

BTC: ***REMOVED***

## License

Code released under [the MIT license](LICENSE.txt).