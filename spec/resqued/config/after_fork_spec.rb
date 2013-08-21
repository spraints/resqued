require 'spec_helper'
require 'resqued/config/after_fork'

describe Resqued::Config::AfterFork do
  # Run the after_fork block.
  #
  #    after_fork do
  #      require "./config/environment.rb"
  #      Rails.application.eager_load!
  #    end
  #
  # ignore calls to any other top-level method.
end
