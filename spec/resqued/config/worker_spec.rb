require 'spec_helper'
require 'resqued/config/worker'

describe Resqued::Config::Worker do
  # Create a bunch of Resqued::Worker objects from
  #
  #    workers do |x|
  #      x.work_on 'queue1'
  #      x.work_on 'queue2'
  #      x.work_on 'queue3', 'queue4'
  #      x.work_on '*'
  #    end
  #
  # and / or
  #
  #    worker_pool(20) do |x|
  #      x.queue 'low', '20%'
  #      x.queue 'normal', 10
  #      x.queue '*'
  #    end
  #
  # or
  #
  #     worker_pool(20) # implies all workers work all queues.
  #
  # ignore calls to any other top-level method.
end
