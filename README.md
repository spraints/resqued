# resqued - a long-running daemon for resque workers.

[image of a ninja rescuing an ear of corn]

resqued provides a resque worker that works well with
slow jobs and continuous delivery.

## Installation

Install by adding resqued to your Gemfile

    gem 'resqued'

## Set up

Let's say you were running workers like this:

    rake resque:work QUEUE=high        &
    rake resque:work QUEUE=high        &
    rake resque:work QUEUE=slow        &
    rake resque:work QUEUE=medium      &
    rake resque:work QUEUE=medium,low  &

To run the same fleet of workers with resqued, create a config file
`config/resqued.rb` like this:

    workers do |x|
      2.times { x.work_on 'high' }
      x.work_on 'slow'
      x.work_on 'medium'
      x.work_on 'medium', 'low'
    end

    before_fork do
      require "./config/environment.rb"
      Rails.application.eager_load!
      ActiveRecord::Base.connection.disconnect!
    end

    after_fork do |worker|
      # `worker.reconnect` already happens
      ActiveRecord::Base.establish_connection
    end

Another syntax for workers:

    worker_pool(20) do |x|
      x.queue 'low', '20%'
      x.queue 'normal', '70%'
      x.queue '*'
    end

Run it like this:

    resqued config/resqued.rb

Or like this to daemonize it:

    resqued -p tmp/pids/resqued-master.pid -D config/resqued.rb

When resqued is running, it has the following processes:

* master - brokers signals to child processes.
* queue reader - retrieves jobs from queues and forks worker processes.
* worker - runs a single job.

## Signals

The following signals are handled by the resqued master process:

* HUP - reread config file and gracefully restart all workers.
* INT / TERM - immediately kill all workers and shut down.
* QUIT - graceful shutdown. Waits for workers to finish.

This is how the signals flow:

```
                  master    listener    worker
                  ------    --------    ------
restart            HUP   -> QUIT     -> QUIT
exit now           INT   ->  INT (default)
exit now          TERM   -> TERM (default)
exit when ready   QUIT   -> QUIT     -> QUIT
```

Resque 1.23.0 uses these signal semantics:

```
TERM: Shutdown immediately, stop processing jobs.
 INT: Shutdown immediately, stop processing jobs.
QUIT: Shutdown after the current job has finished processing.
USR1: Kill the forked child immediately, continue processing jobs.
USR2: Don't process any new jobs
CONT: Start processing jobs again after a USR2
```
