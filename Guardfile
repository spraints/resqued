notification :off

guard 'bundler', :cli => '--local' do
  watch('Gemfile')
  watch('resqorn.gemspec')
end

rspec_options = {
  after_all_pass: false,
  all_on_start:   false,
  keep_failed:    false,
  cli:            '-f h -o rspec.html -f p',
}

guard 'rspec', rspec_options do
  watch('Gemfile.lock')                { 'spec' }

  watch(%r{^spec/.+_spec\.rb$})

  watch(%r{^spec/(support|fixtures)/.*\.rb}) { 'spec' }
  watch('spec/spec_helper.rb')               { 'spec' }

  watch(%r{^lib/(.*)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/resqued/config/(.*)_fork\.rb$}) { |m| "spec/resqued/config/fork_event_spec.rb" }
  watch(%r{^lib/resqued/config/dsl\.rb$}) { |m| "spec/resqued/config" }

end
