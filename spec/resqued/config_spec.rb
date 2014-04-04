require 'spec_helper'
require 'fileutils'
require 'resqued/config'

describe Resqued::Config do
  context do
    around do |example|
      $test_val = :not_set
      Dir.mktmpdir do |dir|
        @config_file = make_file(dir, "config/resqued.rb", "require_relative '../lib/file.rb'\nworker 'example'\n")
        make_file(dir, "lib/file.rb", "$test_val = :ok\n")
        example.call
      end
    end
    let(:config) { Resqued::Config.new([@config_file]) }

    it("can require_relative") { config.build_workers ; expect($test_val).to eq(:ok) }

    def make_file(dir, relative_path, content)
      File.join(dir, relative_path).tap do |path|
        FileUtils.mkpath File.dirname(path)
        File.write(path, content)
      end
    end
  end
end
