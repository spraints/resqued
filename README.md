resqued - resque process manager
================================

This is a master/worker style process manager for [Resque](https://github.com/resque/resque).
It manages a configurable number of worker processes spawned from a single
master and supports a number of signals for controlling worker process
concurrency and lifecycle.

### Features

 - Environment preloading, fast worker spawning, and COW memory sharing via
   single master process.
 - Respawning of failed or stuck workers.
 - Configurable worker process concurrency.
 - Configure queues to be processed by a percentage subset of worker processes.
 - Single pid file for daemonized environments.
 - Master process signal handling: INT/TERM (immediate shutdown),
   QUIT (graceful shutdown), HUP (reload), USR1 (logs), USR2 (reexec),
   WINCH (stop all), TTIN (increase workers), TTOU (decrease workers).

### Usage

    $ resqued --help
    Usage: resqued [-D] [-r <lib>] [-n <count>] [--queue <name>[=<num>%]]...
    Start the resque process manager and spawn worker processes.

    Options
      -n, --workers <count>         Number of worker processes for all queues.
          --queue <name>[=<num>]    Work queue with a percentage (10%) or fixed
                                    number (10) of workers.
          --redis <url>             Connect to redis server at <url>.
      -r, --require <lib>           Require ruby library in master.
      -D, --daemonize               Run daemonized in the background.
      -v, --verbose                 Increase log verbosity; lots of debug info.
      -q, --quiet                   Decrease log verbosity; errors only.

    Queues added first are processed fully before subsequent queues. Backlog on
    the first queue means workers will not visit the second queue.

### Why?

The resqued utility addresses a few different issues we've run into at GitHub
running Resque in production under its default new-process-per-worker model:

  - Each worker process must load the entire Ruby/Rails environment on boot.
    Starting 100 workers quickly can spike load considerable due to the CPU
    intense nature of loading a large set of Ruby libraries. The master/worker
    model allows the environment to be loaded once and individual worker processes
    to spawn very quickly.

  - Managing complex queue/worker configuration is a pain. We have a number of
    queues that are processed by only a subset of a larger worker pool (e.g.,
    a queue being rolled out for the first time that only 5 of 50 workers
    process). Increasing and decreasing queue/worker concurrency currently
    requires modifying a [god](http://godrb.com/) config and restarting the main
    god process, which is outside of our normal deploy process and fairly
    invasive. Moving this type of queue/worker configuration into a separate
    config file managed by a single master process simplifies these types of
    activities.

  - Basic worker process lifecycle management. Restarting or stopping all
    workers, reopening logs, increasing/decreasing workers on the fly all
    requires considerable work to deal with each worker process individually.
    Instead of managing pid files and sending signals to each worker process
    individually, we'd prefer to deal with a single master that does these
    things well.

In general, we've come to appreciate the master/worker model a great deal for
Ruby daemon programs that rely on process based concurrency. This is based
largely on our experience working with [unicorn](http://unicorn.bogomips.org/),
which resqued borrows many concepts from. The alternative of using a generic
process manager like god, monit, bluepill, upstart, etc. to manage individual
worker processes leaves a lot to be desired.

### Configuration

NOTE: This section explores a configuration language that isn't implemented yet.
It's meant to have rough parity with the command line options supported by
resqued but also allow easily hooking into the various worker process lifecycle
events.

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

### License

The resqued utility is Copyright (c) 2013 by [Ryan Tomayko](https://tomayko.com)
and distributed under the terms of the MIT license. See the COPYING file for
more information.
