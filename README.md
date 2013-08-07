# resqorn - unicorn-style resque worker

[image of a ninja rescuing an ear of corn]

resqorn provides a resque worker that works well with
slow jobs and continuous delivery.

## Installation

Install by adding resqorn to your Gemfile

    gem 'resqorn'

## Set up

Let's say you were running workers like this:

    rake resque:work QUEUE=high        &
    rake resque:work QUEUE=high        &
    rake resque:work QUEUE=slow        &
    rake resque:work QUEUE=medium      &
    rake resque:work QUEUE=medium,low  &

To run the same fleet of workers with resqorn, create a config file
`config/resqorn.rb` like this:

    base = File.expand_path('..', File.dirname(__FILE__))
    pidfile File.join(base, 'tmp/pids/resqorn.pid')

    worker do
      workers 2
      queue 'high'
    end

    worker do
      queue 'slow'
      timeout -1 # never time out
    end

    worker do
      queue 'medium'
    end

    worker do
      queues 'medium', 'low'
    end

Run it like this:

    resqorn config/resqorn.rb

When resqorn is running, it has the following processes:

* master - brokers signals to child processes.
* queue reader - retrieves jobs from queues and forks worker processes.
* worker - runs a single job.

The following signals are handled by the resqorn master process:

* HUP - reread config file and restart all workers.
* INT / TERM - immediately kill all workers and shut down.
* QUIT - graceful shutdown. Waits for workers to finish or time out before shutting down.
