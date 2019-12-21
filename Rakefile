require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = '-f doc'
end

desc "Test daemon start/restart/stop"
task :test_restart do
  sh "spec/test_restart.sh"
end

desc "Run all tests"
task :tests => [:spec, :test_restart]

desc "Check syntax"
task :rubocop do
  rubocop "--parallel"
end

namespace :rubocop do
  desc "Reformat files to conform to rubocop rules"
  task :fix do
    rubocop "--auto-correct"
  end

  task :fast do
    rubocop "--fail-fast"
  end
end

def rubocop(*args)
  sh "rubocop", "-c", ".rubocop.yml", *args
end

task :default => [:tests, :rubocop]
