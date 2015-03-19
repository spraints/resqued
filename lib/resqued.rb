require 'resqued/master'
require 'resqued/version'

module Resqued
  START_CTX = {}

  def self.capture_start_ctx!
    START_CTX['$0'] = $0.dup
  end
end
