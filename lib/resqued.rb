require "resqued/master"
require "resqued/version"

module Resqued
  START_CTX = {} # rubocop: disable Style/MutableConstant

  def self.capture_start_ctx!
    START_CTX["$0"] = $0.dup
    START_CTX["pwd"] =
      begin
        env_pwd = ENV["PWD"]
        env_pwd_stat = File.stat env_pwd
        dir_pwd_stat = File.stat Dir.pwd
        if env_pwd_stat.ino == dir_pwd_stat.ino && env_pwd_stat.dev == dir_pwd_stat.dev
          env_pwd
        else
          Dir.pwd
        end
      rescue
        Dir.pwd
      end
  end
end
