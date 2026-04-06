lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cgminer_api_client/version'

Gem::Specification.new do |spec|
  spec.name          = "cgminer_api_client"
  spec.version       = CgminerApiClient::VERSION
  spec.authors       = ["Justin Ramos"]
  spec.email         = ["justin.ramos@gmail.com"]
  spec.summary       = "A gem that allows sending API commands to a pool of cgminer instances"
  spec.description   = "Ruby client for the cgminer JSON API. Supports querying a single miner or a pool of miners in parallel, with full coverage of read-only and privileged commands."
  spec.homepage      = "https://github.com/jramos/cgminer_api_client"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.glob([
    "lib/**/*.rb",
    "bin/*",
    "config/*.example",
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md",
    "cgminer_api_client.gemspec"
  ])
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
