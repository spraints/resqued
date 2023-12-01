# resqued - a long-running daemon for resque workers.

Resqued is a multi-process daemon that controls and monitors a pool of resque workers. It works well with slow jobs and continuous delivery.

![CI status](https://github.com/spraints/resqued/actions/workflows/ruby.yml/badge.svg)

## Installation

Install by adding resqued to your Gemfile

    gem 'resqued'

Run resqued with a config file, like this:

    resqued config/resqued.rb

Or like this to daemonize it:

    resqued -p tmp/pids/resqued-master.pid -D config/resqued.rb

## Configuring workers

Let's say you were running workers like this:

    rake resque:work QUEUE=high        &
    rake resque:work QUEUE=high        &
    rake resque:work QUEUE=slow        &
    rake resque:work QUEUE=medium      &
    rake resque:work QUEUE=medium,low  &

To run the same fleet of workers with resqued, create a config file
`config/resqued.rb` like this:

    2.times { worker 'high' }
    worker 'slow'
    worker 'medium'
    worker 'medium', 'low'

Another syntax for workers:

    worker_pool 5
    queue 'low', :percent => 20
    queue 'normal', :percent => 60
    queue '*'

This time, you'd end up with something similar to this:

    rake resque:work QUEUE=low,normal,* &
    rake resque:work QUEUE=normal,*     &
    rake resque:work QUEUE=normal,*     &
    rake resque:work QUEUE=*            &
    rake resque:work QUEUE=*            &

`worker` and `worker_pool` accept a hash of options that will be passed to `Resqued::Worker`. The supported options are:

* `:interval` - The interval to pass to `Resque::Worker#run`.

## Launching in production.

Resqued consists of three types of processes: master, listener, and worker. The master process only loads code from the resqued gem, and it tries to converge on running exactly one listener. The listener process loads your app's code (via the `before_fork` hook) and launches the workers you've configured. Each worker is a single process.

Resqued restarts on SIGHUP by starting a new listener, and then replacing workers from the old pool with workers in the new pool. Note that this means that if you change the version of Resqued in your bundle, the master and listener processes will be using different versions. This is completely safe (except as noted in CHANGES.md). But, to help with transitions between versions, you can use `kill -USR1` to tell the master process to re-exec itself, which will get the master and listener processes in sync again.

There are two main recommendations for running in production:

* If you use bundler to install resqued, tell it to generate a binstub for resqued. Invoke this binstub (e.g. `bin/resqued`) when you start resqued.

* Specify a pid file using the `-p` option. This pidfile will have the PID of the master process. See [docs/signals.md](docs/signals.md) for more information about which signals are supported.

If your application is running from a symlinked dir (for example, [capistrano's "current" symlink](http://capistranorb.com/documentation/getting-started/structure/)), you'll need to do two more things:

* Ensure that your resqued master process is at least 0.7.13 (`ps o args= $RESQUED_MASTER_PID` should start with "resqued-0.7.13" or higher).

* Explicitly set the `BUNDLE_GEMFILE` environment variable to the symlink dir of your app.

* If you're invoking resqued from something that resolves symlinks in `pwd`, you'll also want to explicitly set the `PWD` environment variable.

Putting all of the above advice together, here's a sample that you could use as a systemd unit:

```
# fragment of resqued.service

[Service]
Type=simple

WorkingDirectory=/opt/app/current
ExecStart=bin/resqued config/resqued.rb
ExecReload=/bin/kill -HUP $MAINPID
```

## Compatibility with Resque

Resqued does not automatically split comma-separated lists of queues in
environment variables like Resque does. To continue using comma-separated
lists, split them in your resqued config file:

    queue (ENV["QUEUE"] || "*").split(',')

## Loading your application

An advantage of using resqued (over `rake resque:work`) is that you can load your application just once, before forking all the workers.

For a Rails application, you might do this:

    before_fork do
      require "./config/environment.rb"
      Rails.application.eager_load!
      # `before_fork` runs in the Listener, and it doesn't actually run any application code.
      ActiveRecord::Base.connection.disconnect!
    end

    after_fork do |resque_worker|
      # Set up a new connection to the database.
      ActiveRecord::Base.establish_connection
      # `resque_worker.reconnect` already happens
    end

## Customizing Resque::Worker

You can configure the Resque worker in the `after_fork` block

    after_fork do |resque_worker|
      # Do not fork to `perform` jobs.
      resque_worker.cant_fork = true

      # Wait a loooong time on SIGTERM.
      resque_worker.term_timeout = 1.day

      resque_worker.run_at_exit_hooks = true

      Resque.before_first_fork do
        # ...
      end
    end

## Full config file example

    worker 'high'
    worker 'low', :interval => 30

    worker_pool 5, :interval => 1
    queue 'high', 'almosthigh'
    queue 'low', :percent => 20
    queue 'normal', :count => 4
    queue '*'

    before_fork do
      require "./config/environment.rb"
      Rails.application.eager_load!
      ActiveRecord::Base.connection.disconnect!
    end

    after_fork do |worker|
      ActiveRecord::Base.establish_connection
      worker.term_timeout = 1.minute
    end

    after_exit do |worker_summary|
        puts "Worker was alive for #{worker_summary.alive_time_sec}"
        puts "Process::Status of exited worker: #{worker_summary.process_status.inspect}"
    end

In this example, a Rails application is being set up with 7 workers:
* high
* low (interval = 30)
* high, almosthigh, low, normal, * (interval = 1)
* high, almosthigh, normal, * (interval = 1)
* high, almosthigh, normal, * (interval = 1)
* high, almosthigh, normal, * (interval = 1)
* high, almosthigh, * (interval = 1)

## Multiple configurations

If your app has several work machines, each with the same application code but different sets of workers, you might want to have a shared config file for the `before_fork` and `after_fork` blocks. You can pass in several config files, and resqued will act as if you concatenated them.

    $ resqued config/shared.rb config/pool-a.rb
    $ resqued config/shared.rb config/pool-b.rb

## Testing

To test your resqued configuration, add a test case like this:

```
class MyResquedTest < Test::Unit::TestCase
  include Resqued::TestCase
  def test_resqued_config
    assert_resqued 'config/resqued.rb'
  end
end
```

## See also

For information about how resqued works, see the [documentation](docs/).
