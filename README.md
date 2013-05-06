resqued - resque process manager
================================

This is a run environment for Resque.

Features:

 - COW children / environment preloading
 - Configurable worker process concurrency.
 - Assign queues to percentage subset of worker processes.
 - Signals: INT/TERM, QUIT, HUP (reload), USR1 (logs), USR2 (reexec), WINCH,
   TTIN, TTOU.

Command line:

    Usage: resqued [-D] [-c <config>] [-q high=20%]...
    Start the resqued server.

    Options:
      -D, --daemonize             Run daemonized in the background.
      -c, --config <config>       Load resqued config file at <config>
      -w, --workers <count>       Number of workers to start for all queues.
      -q, --queue <name>[=<val>]  Process the queue with a percentage (10%)
                                  or fixed number (10) of workers.

    Queues added first are processed fully before subsequent queues. Backlog on
    the first queue means workers will not visit the second queue.

Configuration:

    preload_app true
    stderr_path "/var/log/resqued.log"
    stdout_path "/var/log/resqued.log"
    worker_processes 32

    queue 'critical'   # all workers on critical queue
    queue 'high', 20   # only 20 workers on high queue
    queue 'low', 0.10  # only 10% (3) workers on low queue
    queue '*', :all

    # clean up before exec'ing new master
    before_exec do
    end

    # called in the master before forking each worker
    before_fork do
    end

    # called in the worker immediately after forking
    after_fork do
      Service.reconnect!
    end
