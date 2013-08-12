module Resqued
  class Config
    # Public: Build a new config instance from the given file.
    def self.load_file(filename)
      new.load_file(filename)
    end

    # Public: Build a new config instance from the given `config` script.
    def self.load_string(config, filename = nil)
      new.load_string(config, filename)
    end

    # Public: Build a new config instance.
    def initialize
      @workers = []
    end

    # Public: The configured pidfile path, or nil.
    attr_reader :pidfile
    
    # Public: An array of configured workers.
    attr_reader :workers

    # Public: Add to this config using the script `config`.
    def load_string(config, filename = nil)
      DSL.new(self)._apply(config, filename)
      self
    end

    # Public: Add to this config using the script in the given file.
    def load_file(filename)
      load_string(File.read(filename), filename)
    end

    # Private.
    class DSL
      def initialize(config)
        @config = config
      end

      # Internal.
      def _apply(script, filename)
        if filename.nil?
          instance_eval(script)
        else
          instance_eval(script, filename)
        end
      end

      # Public: Set the pidfile path.
      def pidfile(path)
        raise ArgumentError unless path.is_a?(String)
        _set(:pidfile, path)
      end

      # Public: Define a worker.
      def worker
        @current_worker = {:size => 1, :queues => []}
        yield
        _push(:workers, @current_worker)
        @current_worker = nil
      end

      # Public: Add queues to a worker
      def queues(*queues)
        queues = [queues].flatten.map { |q| q.to_s }
        @current_worker[:queues] += queues
      end
      alias queue queues

      # Public: Set the number of workers
      def workers(count)
        raise ArgumentError unless count.is_a?(Fixnum)
        @current_worker[:size] = count
      end

      # Private.
      def _set(instance_variable, value)
        @config.instance_variable_set("@#{instance_variable}", value)
      end

      # Private.
      def _push(instance_variable, value)
        @config.instance_variable_get("@#{instance_variable}").push(value)
      end
    end
  end
end
