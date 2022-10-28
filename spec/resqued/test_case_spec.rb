require "spec_helper"
require "resqued/test_case"

describe Resqued::TestCase do
  let(:test_case) { Object.new.extend(the_module) }

  context "LoadConfig" do
    let(:the_module) { described_class::LoadConfig }
    it { expect { test_case.assert_resqued "spec/fixtures/test_case_environment.rb", "spec/fixtures/test_case_clean.rb"              }.not_to raise_error }
    it { expect { test_case.assert_resqued "spec/fixtures/test_case_environment.rb", "spec/fixtures/test_case_before_fork_raises.rb" }.to     raise_error(RuntimeError) }
    it { expect { test_case.assert_resqued "spec/fixtures/test_case_environment.rb", "spec/fixtures/test_case_after_fork_raises.rb"  }.to     raise_error(RuntimeError) }
    it { expect { test_case.assert_resqued "spec/fixtures/test_case_environment.rb", "spec/fixtures/test_case_after_exit_raises.rb"  }.to     raise_error(RuntimeError) }
    it { expect { test_case.assert_resqued "spec/fixtures/test_case_environment.rb", "spec/fixtures/test_case_no_workers.rb"         }.not_to raise_error }
  end
end
