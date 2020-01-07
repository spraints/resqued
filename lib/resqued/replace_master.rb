require "tempfile"
require "yaml"

module Resqued
  class ReplaceMaster
    # Public: Replace the current master process with a new one, while preserving state.
    def self.exec!(state)
      exec Resqued::START_CTX["$0"], "--replace", store_state(state), exec_opts(state)
    end

    # Internal: Returns exec options for each open socket in 'state'.
    def self.exec_opts(state)
      exec_opts = {}
      state.sockets.each do |sock|
        exec_opts[sock.to_i] = sock
      end
      if pwd = Resqued::START_CTX["pwd"]
        exec_opts[:chdir] = pwd
      end
      return exec_opts
    end

    # Internal: Write out current state to a file, so that a new master can pick up from where we left off.
    def self.store_state(state)
      data = { version: Resqued::VERSION }
      data[:start_ctx] = Resqued::START_CTX
      data[:state] = state.to_h

      f = Tempfile.create "resqued-state"
      f.write(YAML.dump(data))
      f.close
      return f.path
    end

    # Internal: Restore the master's state, and remove the state file.
    def self.restore_state(state, path)
      data = YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: true)
      Resqued::START_CTX.replace(data[:start_ctx] || {})
      state.restore(data[:state])
      File.unlink(path) rescue nil
    end
  end
end
