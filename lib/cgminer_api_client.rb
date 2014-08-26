require 'json'
require 'socket'
require 'thread'
require 'yaml'

require "cgminer_api_client/miner"
require "cgminer_api_client/miner/commands"
require "cgminer_api_client/miner_pool"
require "cgminer_api_client/socket"
require "cgminer_api_client/version"

module CgminerApiClient
  def self.default_timeout
    defined?(@default_timeout) ? @default_timeout : 5
  end

  def self.default_timeout=(value)
    @default_timeout = value
  end

  def self.default_port
    defined?(@default_port) ? @default_port : 4028
  end

  def self.default_port=(value)
    @default_port = value
  end

  def self.config
    yield self if block_given?
  end
end