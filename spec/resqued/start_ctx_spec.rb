require "spec_helper"
require "tmpdir"
require "resqued"

describe "Resqued::START_CTX" do
  before do
    Resqued::START_CTX.clear
  end

  it "captures '$0'" do
    Resqued.capture_start_ctx!
    expect(Resqued::START_CTX["$0"]).to be_a(String)
  end

  it "captures pwd" do
    Resqued.capture_start_ctx!
    expect(Resqued::START_CTX["pwd"]).to eq(Dir.pwd)
  end

  it "captures pwd without resolving symlinks" do
    tmpdir = Dir.mktmpdir
    begin
      realdir = File.expand_path("#{tmpdir}/realdir")
      linkdir = File.expand_path("#{tmpdir}/linked")

      Dir.mkdir realdir
      File.symlink "realdir", linkdir

      original_pwd, ENV["PWD"] = ENV["PWD"], linkdir
      Dir.chdir linkdir do
        Resqued.capture_start_ctx!
        expect(Resqued::START_CTX["pwd"]).to eq(linkdir)
      end
    ensure
      ENV["PWD"] = original_pwd
      FileUtils.remove_entry_secure(tmpdir)
    end
  end

  it "captures pwd when ENV['PWD'] is wrong" do
    tmpdir = Dir.mktmpdir
    begin
      realdir = File.expand_path("#{tmpdir}/realdir")
      linkdir = File.expand_path("#{tmpdir}/linked")

      Dir.mkdir realdir
      File.symlink "realdir", linkdir

      Dir.chdir linkdir do
        Resqued.capture_start_ctx!
        expect(Resqued::START_CTX["pwd"]).to eq(Dir.pwd)
      end
    ensure
      FileUtils.remove_entry_secure(tmpdir)
    end
  end
end
