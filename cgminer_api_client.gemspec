# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cgminer_api_client/version'

Gem::Specification.new do |spec|
  spec.name          = "cgminer_api_client"
  spec.version       = CgminerApiClient::VERSION
  spec.authors       = ["Justin Ramos"]
  spec.email         = ["justin.ramos@gmail.com"]
  spec.summary       = %q{A gem that allows sending API commands to a pool of cgminer instances}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/jramos/cgminer_api_client"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler" ,   "~> 2.0"
  spec.add_development_dependency "pry" ,       "~> 0.12.0"
  spec.add_development_dependency "rake" ,      "~> 13.0.0"
  spec.add_development_dependency 'rspec' ,     "~> 3.9"
  spec.add_development_dependency "simplecov" , "~> 0.17.0"
end
