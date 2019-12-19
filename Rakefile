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

task :default => :tests
