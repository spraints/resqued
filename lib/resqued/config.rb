require 'resqued/config/after_fork'
require 'resqued/config/before_fork'
require 'resqued/config/worker'

module Resqued
  module Config
    # Public: Build a new ConfigFile instance.
    #
    # Resqued::Config is a module because the evaluators say so, so this `new` is a factory for another class.
    def self.new(paths)
      MultiConfigFile.new(paths.map { |path| ConfigFile.new(path) }
    end

    # Does the things that the config file says to do.
    class ConfigFile
      def initialize(config_path)
        @path = config_path
        @contents = File.read(@path)
      end

      # Public: Performs the `before_fork` action from the config.
      def before_fork
        Resqued::Config::BeforeFork.new.apply(@contents, @path)
      end

      # Public: Performs the `after_fork` action from the config.
      def after_fork(worker)
        Resqued::Config::AfterFork.new(:worker => worker).apply(@contents, @path)
      end

      # Public: Builds the workers specified in the config.
      def build_workers(options = {})
        Resqued::Config::Worker.new({:config => self}.merge(options)).apply(@contents, @path)
      end
    end

    # Multiplexes config things to multiple config files.
    class MultiConfigFile
      def initialize(configs)
        @configs = configs
      end

      # Public.
      def before_fork
        @configs.each { |config| config.before_fork }
      end

      # Public.
      def after_fork(worker)
        @configs.each { |config| config.after_fork(worker) }
      end

      # Public.
      def build_workers
        @configs.inject([]) { |workers, config| workers + config.build_workers(:config => self) }
      end
    end
  end
end
