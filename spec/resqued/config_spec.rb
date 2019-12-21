require "spec_helper"

require "fileutils"
require "tmpdir"

require "resqued/config"

describe Resqued::Config do
  context do
    around do |example|
      $test_val = :not_set
      $other_test_val = :not_set
      Dir.mktmpdir do |dir|
        @config_file = make_file(dir, "config/resqued.rb", "require_relative '../lib/file'\nworker 'example'\n")
        make_file(dir, "lib/file.rb", "require_relative 'file2'\n$test_val = :ok\n")
        make_file(dir, "lib/file2.rb", "$other_test_val = :ok\n")
        example.call
      end
    end
    let(:config) { Resqued::Config.new([@config_file]) }

    it("can require_relative") { config.build_workers; expect($test_val).to eq(:ok) }
    it("does not override require_relative in required files") { config.build_workers; expect($other_test_val).to eq(:ok) }

    def make_file(dir, relative_path, content)
      File.join(dir, relative_path).tap do |path|
        FileUtils.mkpath File.dirname(path)
        File.write(path, content)
      end
    end
  end
end
