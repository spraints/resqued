require 'resqued/config/base'

module Resqued
  module Config
    # A config handler that builds workers.
    #
    # No worker processes are spawned by this class.
    class Worker < Base
      # Public.
      def initialize(options = {})
        @worker_class = options.fetch(:worker_class) { Resqued::Worker }
      end

      # DSL: Create workers with the "literal" DSL.
      #
      #     workers(:interval => 3) do |x|
      #       x.work_on 'one', 'two'
      #       x.work_on 'three'
      #       x.work_on 'four', :interval => 20
      #     end
      def workers(options = {})
        dsl = LiteralDsl.new(@worker_class, options)
        yield dsl
        @workers = dsl._workers
      end

      # DSL: Create workers with the "intent" DSL.
      #
      #     worker_pool(20, :interval => 3) do |x|
      #       x.queue 'one', '20%'
      #       x.queue 'two', 10
      #       x.queue '*'
      #     end
      def worker_pool(count, options = {})
        dsl = IntentDsl.new(count, @worker_class, options)
        if block_given?
          yield dsl
        else
          dsl.queue('*', count)
        end
        @workers = dsl._workers
      end

      private

      # Private: The created workers, returned from `Base#apply`.
      def results
        @workers
      end

      # Object passed to the block in `Worker#workers`.
      class LiteralDsl
        # Internal.
        def initialize(worker_class, options)
          @worker_class = worker_class
          @default_options = options
          @workers = []
        end

        # Public: Set up a worker to work on certain queues.
        def work_on(*queues)
          options = queues.last.is_a?(Hash) ? queues.pop : {}
          @workers << @worker_class.new(queues, @default_options.merge(options))
        end

        # Internal: Get the created workers.
        def _workers
          @workers
        end
      end

      # Object passed to the block in `Worker#worker_pool`.
      class IntentDsl
        # Internal.
        def initialize(count, worker_class, options)
          @count = count
          @worker_class = worker_class
          @worker_options = options
          @queues = {}
        end

        # Public: Define how much of the worker pool should work on a given queue.
        def queue(queue_name, concurrency = @count)
          @queues[queue_name] =
            case concurrency
            when nil, '';    1.0
            when /%$/;       concurrency.chomp('%').to_i * 0.01
            else             concurrency.to_i
            end
        end

        # Internal: Build and returns the workers.
        #
        # Build an array of Worker objects with queue lists configured based
        # on the concurrency values established and the total number of workers.
        def _workers
          workers = []
          queues = _fixed_concurrency_queues
          @count.times do |slot|
            worker_num = slot + 1
            queue_names = queues.
              select { |name, concurrency| concurrency >= worker_num }.
              map { |name, _| name }
            if queue_names.any?
              workers.push @worker_class.new(queue_names, @worker_options)
            end
          end
          workers
        end

        # Internal: Like @queues but with concrete fixed concurrency values. All
        # percentage based concurrency values are converted to fixnum total number
        # of workers that queue should run on.
        def _fixed_concurrency_queues
          @queues.map { |name, concurrency| [name, _translate_concurrency_value(concurrency)] }
        end

        # Internal: Convert a queue worker concurrency value to a fixed number of
        # workers. This supports values that are fixed numbers as well as percentage
        # values (between 0.0 and 1.0). The value may also be nil, in which case the
        # maximum worker_processes value is returned.
        def _translate_concurrency_value(value)
          case
          when value.nil?
            @count
          when value.is_a?(Fixnum)
            value < @count ? value : @count
          when value.is_a?(Float) && value >= 0.0 && value <= 1.0
            (@count * value).to_i
          else
            raise TypeError, "Unknown concurrency value: #{value.inspect}"
          end
        end
      end
    end
  end
end
