require File.expand_path('lib/resqued/version', File.dirname(__FILE__))
Gem::Specification.new do |s|
  s.name    = 'resqued'
  s.version = Resqued::VERSION
  s.summary = s.description = 'Daemon of resque workers'
  s.homepage = 'https://github.com'
  s.authors = ["Matt Burke"]
  s.email   = 'spraints@gmail.com'
  s.files   = Dir['lib/**/*', 'README.md']
  s.bindir  = 'exe'
  s.executables = %w(
    resqued
    resqued-listener
  )
  s.add_dependency 'kgio', '~> 2.6'
  s.add_dependency 'resque', '>= 1.8.0'
  s.add_development_dependency 'debugger'
  s.add_development_dependency 'rspec', '~> 2.0'
  s.add_development_dependency 'rake', '~> 0.9.0'
  s.add_development_dependency 'guard-rspec', '~> 2.4.1'
  s.add_development_dependency 'guard-bundler', '~> 1.0.0'
  s.add_development_dependency 'rb-fsevent'
end
