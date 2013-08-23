module Resqued
  module Config
    # Defines the DSL for resqued config files.
    #
    # Each subclass should override parts of the dsl that it cares about.
    module Dsl
      # Public: Define a block to be run once, before forking all the workers.
      def before_fork(&block)
      end

      # Public: Define a block to be run in each worker.
      def after_fork(&block)
      end

      # Public: Define a worker that will work on a queue.
      def worker(*queues)
      end

      # Public: Define a pool of workers that will work '*', or the queues specified by `queue`.
      def worker_pool(count, options = {})
      end

      # Public: Define the queues worked by members of the worker pool.
      def queue(queue_name, concurrency = nil)
      end
    end
  end
end
