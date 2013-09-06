require 'resqued/config/base'
require 'resqued/worker'

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
        options = queues.last.is_a?(Hash) ? queues.pop : {}
        queues = ['*'] if queues.empty?
        @workers << @worker_class.new(options.merge(@worker_options).merge(:queues => queues.flatten))
      end

      # DSL: Set up a pool of workers. Define queues for the members of the pool with `queue`.
      #
      #     worker_pool 20, :interval => 1
      def worker_pool(count, options = {})
        @pool_size = count
        @pool_options = options
        @pool_queues = {}
      end

      # DSL: Define a queue for the worker_pool to work from.
      #
      #     queue 'one'
      #     queue '*'
      #     queue 'two', '10%'
      #     queue 'three', 5
      #     queue 'four', :percent => 10
      #     queue 'five', :count => 5
      def queue(queue_name, concurrency = nil)
        @pool_queues[queue_name] =
          case concurrency
          when Hash
            if percent = concurrency[:percent]
              percent * 0.01
            elsif count = concurrency[:count]
              count
            else
              1.0
            end
          when nil, '';    1.0
          when /%$/;       concurrency.chomp('%').to_i * 0.01
          else             concurrency.to_i
          end
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
          queue_names = queues.
            select { |name, concurrency| concurrency >= worker_num }.
            map { |name, _| name }
          if queue_names.any?
            worker(queue_names, @pool_options)
          else
            worker('*', @pool_options)
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
        case
        when value.nil?
          @pool_size
        when value.is_a?(Fixnum)
          value < @pool_size ? value : @pool_size
        when value.is_a?(Float) && value >= 0.0 && value <= 1.0
          (@pool_size * value).to_i
        else
          raise TypeError, "Unknown concurrency value: #{value.inspect}"
        end
      end
    end
  end
end
