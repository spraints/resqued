module Resqued
  class ListenerProxyState
    attr_accessor :master_socket
    attr_accessor :options
    attr_accessor :pid
    attr_accessor :worker_pids
  end
end
