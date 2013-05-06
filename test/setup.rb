# Basic test environment.
#
# This should set up the load path for testing only. Don't require any support libs
# or gitrpc stuff in here.

# Load standalone gem load path setup
$LOAD_PATH.unshift File.expand_path("../../vendor/gems", __FILE__)
require 'bundler/setup'

# bring in minitest
require 'minitest/autorun'

# add bin dir to path for testing command
ENV['PATH'] = [
  File.expand_path("../../bin", __FILE__),
  ENV['PATH']
].join(":")
