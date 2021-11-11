require "support/custom_matchers"
require "support/resqued_path"
require "support/resqued_integration_helpers"
require "fileutils"

SPEC_TEMPDIR = File.expand_path("../tmp/spec", File.dirname(__FILE__))
FileUtils.mkpath(SPEC_TEMPDIR)
