# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "trinidad_probe_extension/version"

Gem::Specification.new do |gem|
  gem.name        = "trinidad_probe_extension"
  gem.version     = Trinidad::Extensions::Probe::VERSION

  gem.authors     = ["Karol Bucek"]
  gem.email       = ["self@kares.org"]
  gem.homepage    = "http://github.com/kares/trinidad_probe_extension"

  gem.summary     = %q{Monitoring and Management for Trinidad}
  gem.description = %q{WIP monitoring web-application for Trinidad (based on PSI-Probe).}

  gem.licenses    = ['GPL-2']

  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- test/* spec/*`.split("\n")

  gem.extra_rdoc_files = %w[ README.md LICENSE ]

  gem.require_paths = ["lib"]
  gem.add_dependency 'trinidad', '>= 1.0'
  gem.add_dependency 'ecj_jar', '>= 3.8.0'
  gem.add_development_dependency 'rake'
  #gem.add_development_dependency 'test-unit'
end