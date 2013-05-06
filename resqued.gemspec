# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "resqued"
  s.version     = "1.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = %w[@rtomayko]
  s.email       = ["rtomayko@gmail.com"]
  s.homepage    = "https://github.com/rtomayko/resqued"
  s.description = "resque process manager"
  s.summary     = "..."

  s.add_dependency "resque"

  s.add_development_dependency "rake"
  s.add_development_dependency "minitest"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test`.split("\n").select { |f| f =~ /_test.rb$/ }
  s.bindir        = "script"
  s.executables   = %w[resqued]
  s.require_paths = %w[lib]
end
