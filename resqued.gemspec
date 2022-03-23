require File.expand_path("lib/resqued/version", File.dirname(__FILE__))
Gem::Specification.new do |s|
  s.name    = "resqued"
  s.version = Resqued::VERSION
  s.summary = s.description = "Daemon of resque workers"
  s.homepage = "https://github.com/spraints/resqued"
  s.licenses = ["MIT"]
  s.authors = ["Matt Burke"]
  s.email   = "spraints@gmail.com"
  s.files   = Dir["lib/**/*", "README.md", "CHANGES.md", "MIT-LICENSE", "docs/**/*"]
  s.test_files = Dir["spec/**/*"]
  s.bindir = "exe"
  s.executables = %w[
    resqued
  ]
  s.add_dependency "kgio", "~> 2.6"
  s.add_dependency "mono_logger", "~> 1.0"
  s.add_development_dependency "rake", "13.0.1"
  s.add_development_dependency "resque", ">= 1.9.1"
  s.add_development_dependency "rspec", "3.9.0"
  s.add_development_dependency "rubocop", "0.78.0"
end
