require "resqued/config/base"
require "resqued/worker"

module Resqued
  module Config
    # A config handler that builds workers.
    #
    # No worker processes are spawned by this class.
    class Worker < Base
      # Public.
      def initialize(options = {})
        options = options.dup
        @worker_class = options.delete(:worker_class) || Resqued::Worker
        @worker_options = options
        @workers = []
      end

      # DSL: Create a worker for the exact queues listed.
      #
      #     worker 'one', :interval => 1
      def worker(*queues)
        options = queues.last.is_a?(Hash) ? queues.pop.dup : {}
        queues = queues.flatten
        queues = ["*"] if queues.empty?
        queues = queues.shuffle if options.delete(:shuffle_queues)
        @workers << @worker_class.new(options.merge(@worker_options).merge(queues: queues))
      end

      # DSL: Set up a pool of workers. Define queues for the members of the pool with `queue`.
      #
      #     worker_pool 20, :interval => 1
      def worker_pool(count, *queues)
        @pool_size = count
        @pool_options = queues.last.is_a?(Hash) ? queues.pop : {}
        @pool_queues = {}
        queues.each { |q| queue q }
      end

      # DSL: Define a factory Proc used to create Resque::Workers. The factory
      # Proc receives a list of queues as an argument.
      #
      #    worker_factory { |queues| Resque::Worker.new(*queues) }
      def worker_factory(&block)
        @worker_options.merge!(worker_factory: block)
      end

      # DSL: Define a queue for the worker_pool to work from.
      #
      #     queue 'one'
      #     queue '*'
      #     queue 'four-a', 'four-b', :percent => 10
      #     queue 'five', :count => 5
      def queue(*queues)
        options = queues.last.is_a?(Hash) ? queues.pop : {}
        concurrency =
          case options
          when Hash
            if percent = options[:percent]
              percent * 0.01
            elsif count = options[:count]
              count
            else
              1.0
            end
          else
            1.0
          end
        queues.each { |queue| @pool_queues[queue] = concurrency }
      end

      private

      def results
        build_pool_workers!
        @workers
      end

      # Internal: Build the pool workers.
      #
      # Build an array of Worker objects with queue lists configured based
      # on the concurrency values established and the total number of workers.
      def build_pool_workers!
        return unless @pool_size

        queues = _fixed_concurrency_queues
        1.upto(@pool_size) do |worker_num|
          queue_names = queues
                        .select { |_name, concurrency| concurrency >= worker_num }
                        .map { |name, _concurrency| name }
          if queue_names.any?
            worker(queue_names, @pool_options)
          else
            worker("*", @pool_options)
          end
        end
      end

      # Internal: Like @queues but with concrete fixed concurrency values. All
      # percentage based concurrency values are converted to fixnum total number
      # of workers that queue should run on.
      def _fixed_concurrency_queues
        @pool_queues.map { |name, concurrency| [name, _translate_concurrency_value(concurrency)] }
      end

      # Internal: Convert a queue worker concurrency value to a fixed number of
      # workers. This supports values that are fixed numbers as well as percentage
      # values (between 0.0 and 1.0). The value may also be nil, in which case the
      # maximum worker_processes value is returned.
      def _translate_concurrency_value(value)
        if value.nil?
          @pool_size
        elsif value.is_a?(1.class)
          value < @pool_size ? value : @pool_size
        elsif value.is_a?(Float) && value >= 0.0 && value <= 1.0
          [(@pool_size * value).to_i, 1].max
        else
          raise TypeError, "Unknown concurrency value: #{value.inspect}"
        end
      end
    end
  end
end
