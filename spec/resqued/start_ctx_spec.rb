require "spec_helper"
require "resqued"

describe "Resqued::START_CTX" do
  before do
    Resqued::START_CTX.clear
  end

  it "captures '$0'" do
    Resqued.capture_start_ctx!
    expect(Resqued::START_CTX["$0"]).to be_a(String)
  end
end
