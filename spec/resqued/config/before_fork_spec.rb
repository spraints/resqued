require 'spec_helper'
require 'resqued/config/before_fork'

describe Resqued::Config::BeforeFork do
  # Run the before_fork block.
  #
  #    before_fork do
  #      require "./config/environment.rb"
  #      Rails.application.eager_load!
  #    end
  #
  # ignore calls to any other top-level method.
end
