# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'notifyMe/version'

Gem::Specification.new do |spec|
  spec.name          = "notifyMe"
  spec.version       = NotifyMe::VERSION
  spec.authors       = ["Chris911"]
  spec.email         = ["christophe.naud.dulude@gmail.com"]
  spec.description   = %q{TODO: Write a gem description}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*") + %w(README.md config/example.yml config/schedule.rb)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mongo"
  spec.add_runtime_dependency "bson_ext"
  spec.add_runtime_dependency "snoo"
  spec.add_runtime_dependency "httparty"
  spec.add_runtime_dependency "OpenWeather"
  spec.add_runtime_dependency "PolyNotify"
  spec.add_runtime_dependency "encryptor"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "whenever"
end
