require "resqued/version"

module Resqued
  module ProclineVersion
    def procline_version
      @version ||=
        begin
          # If we've built a custom version, this should show the custom version.
          Gem.loaded_specs["resqued"].version.to_s
        rescue Object
          # If this isn't a gem, fall back to the version in resqued/version.rb.
          Resqued::VERSION
        end
      "resqued-#{@version}"
    end
  end
end
