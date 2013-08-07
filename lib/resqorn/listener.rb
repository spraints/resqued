module Resqorn
  class Listener
    def initialize(options)
    end

    def run
      write_procline
      loop do
        sleep 10
        break
      end
      #load_environment
      #install_sigquit_handler
      #wait_for_jobs
    end

    def write_procline
      $0 = "resqorn listener"
    end
  end
end
