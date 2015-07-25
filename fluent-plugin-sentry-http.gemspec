# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fluent/plugin/sentry_http/version'

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-sentry-http"
  spec.version       = Fluent::Plugin::SentryHttp::VERSION
  spec.authors       = ["IKUTA Masahito"]
  spec.email         = ["cooldaemon@gmail.com"]
  spec.summary       = %q{Fluentd input plugin that receive exceptions from the Sentry clients(Raven).}
  spec.description   = spec.summary
  spec.homepage      = "http://github.com/cooldaemon/fluent-plugin-sentry-http"
  spec.license       = "APLv2"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "fluentd", ">= 0.10.55"
  spec.add_dependency "oj", "~> 1.4.2"
end
