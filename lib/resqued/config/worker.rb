require 'resqued/config/base'

module Resqued
  module Config
    class Worker < Base
      def initialize(options = {})
        @worker_class = options.fetch(:worker_class) { Resqued::Worker }
      end

      def workers(options = {})
        @workers = []
        yield LiteralDsl.new(@workers, @worker_class, options)
      end

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

      def results
        @workers
      end

      class LiteralDsl
        def initialize(workers, worker_class, options)
          @workers = workers
          @worker_class = worker_class
          @default_options = options
        end

        def work_on(*queues)
          options = queues.last.is_a?(Hash) ? queues.pop : {}
          @workers << @worker_class.new(queues, @default_options.merge(options))
        end
      end

      class IntentDsl
        def initialize(count, worker_class, options)
          @count = count
          @worker_class = worker_class
          @worker_options = options
          @queues = {}
        end

        def queue(queue_name, concurrency = @count)
          @queues[queue_name] =
            case concurrency
            when nil, '';    1.0
            when /%$/;       concurrency.chomp('%').to_i * 0.01
            else             concurrency.to_i
            end
        end

        def _workers
          workers = []
          queues = _fixed_concurrency_queues
          @count.times do |slot|
            worker_num = slot + 1
            queue_names = queues.
              select { |name, concurrency| concurrency >= worker_num }.
              map { |name, _| name }
            if queue_names.any?
              workers[slot] = @worker_class.new(queue_names, @worker_options)
            end
          end
          workers
        end

        def _fixed_concurrency_queues
          @queues.map { |name, concurrency| [name, _translate_concurrency_value(concurrency)] }
        end

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
