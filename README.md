# CgminerApiClient

A gem that allows sending API commands to a pool of cgminer instances.

## Installation

Clone this repository.

## Configuration

Copy ``config/miners.yml.example`` to ``config/miners.yml`` and update with the IP addresses (and optional ports) of your cgminer instances. E.g.

    # connect to localhost on the default port (4028)
    - host: 127.0.0.1
    # connect to 192.168.1.1 on a non-standard port (1234)
    - host: 192.168.1.1
      port: 1234

## Note

Your cgminer instances must be configured to allow remote API access if connecting to anywhere but localhost (127.0.0.1). See the [cgminer API-README](https://github.com/ckolivas/cgminer/blob/master/API-README) for more information.

## CLI Usage

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
    pool.devs     # run 'devs' on each miner in the pool
    pool.summary  # run 'summary' on each miner in the pool

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