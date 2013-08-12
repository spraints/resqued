require 'spec_helper'
require 'resqued/config'

describe Resqued::Config do
  let(:config) { described_class.load_string(config_string, config_file_path) }

  let(:config_string) { <<-CONFIG }
    pidfile File.expand_path('my.pid', File.dirname(__FILE__))
    worker do
      queue 'minimal'
    end
    worker do
      workers 2
      queues 'a', 'b'
    end
  CONFIG

  let(:config_file_path) { '/path/to/config/resqued.rb' }

  it { expect(config.pidfile).to eq('/path/to/config/my.pid') }
  it { expect(config.workers).to eq([ {:queues => ['minimal'], :size => 1}, {:queues => ['a', 'b'], :size => 2} ]) }

  context 'with no filename' do
    let(:config_file_path) { nil }
    it('raises no error') { expect(config.pidfile).to match(/my.pid$/) }
  end
end
