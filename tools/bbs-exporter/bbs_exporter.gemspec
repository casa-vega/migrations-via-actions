# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bbs_exporter/version"

Gem::Specification.new do |spec|
  spec.name          = "bbs_exporter"
  spec.version       = BbsExporter::VERSION
  spec.authors       = ["Kyle Macey", "Matthew Duff", "Maxwell Pray", "Daniel Perez", "Michael Johnson"]
  spec.email         = ["kylemacey@github.com", "mattcantstop@github.com", "synthead@github.com", "dpmex4527@github.com", "migarjo@github.com"]

  spec.summary       = "Exports Bitbucket Server data as ghe-migrator archives."
  spec.homepage      = "https://github.com/github/bbs-exporter"

  spec.files         = %w(README.md CODE_OF_CONDUCT.md Rakefile bbs_exporter.gemspec)
  spec.files         += Dir.glob("{bin,exe,lib,script}/**/*")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.4.4"

  spec.add_dependency "activemodel",        "~> 6.1.7.6"
  spec.add_dependency "activerecord",       "~> 6.1.7.6"
  spec.add_dependency "activesupport",      "~> 6.1.7.6"
  spec.add_dependency "addressable",        "~> 2.8.0"
  spec.add_dependency "climate_control",    "~> 0.2.0"
  spec.add_dependency "concurrent-ruby",    "~> 1.1.6"
  spec.add_dependency "dotenv",             "~> 2.7.5"
  spec.add_dependency "faraday",            "~> 1.8.0"
  spec.add_dependency "faraday-http-cache", "~> 2.2.0"
  spec.add_dependency "faraday_middleware", "~> 1.2.0"
  spec.add_dependency "git",                ">= 1.6", "< 1.19"
  spec.add_dependency "mime-types",         "~> 3.3.1"
  spec.add_dependency "posix-spawn",        "~> 0.3.13"
  spec.add_dependency "rainbow",            "~> 3.1.1"
  spec.add_dependency "ruby-progressbar",   "~> 1.10.1"
  spec.add_dependency "ruby-terminfo",      "~> 0.1.1"
  spec.add_dependency "sqlite3",            "~> 1.5.1"
  spec.add_dependency "ssh-fingerprint",    "~> 0.0.3"

  spec.add_development_dependency "bundler",            "~> 2.2.29"
  spec.add_development_dependency "irb",                "~> 1.2.3"
  spec.add_development_dependency "pry-byebug",         "~> 3.9.0"
  spec.add_development_dependency "pry-rescue",         "~> 1.5.2"
  spec.add_development_dependency "pry-stack_explorer", "~> 0.4.9.3"
  spec.add_development_dependency "rake",               "~> 13.0.1"
  spec.add_development_dependency "rdoc",               "~> 6.2"
  spec.add_development_dependency "redcarpet",          "~> 3.5.0"
  spec.add_development_dependency "rspec",              "~> 3.9.0"
  spec.add_development_dependency "rubocop",            "~> 0.75.1"
  spec.add_development_dependency "rubocop-github",     "~> 0.13.0"
  spec.add_development_dependency "timecop",            "~> 0.9.1"
  spec.add_development_dependency "vcr",                "~> 5.1.0"
  spec.add_development_dependency "webmock",            "~> 3.8.3"
  spec.add_development_dependency "yard",               "~> 0.9.24"
end
