# resqued - a long-running daemon for resque workers.

Resqued is a multi-process daemon that controls and monitors a pool of resque workers. It works well with slow jobs and continuous delivery.

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
    queue 'low', '20%'
    queue 'normal', '60%'
    queue '*'

This time, you'd end up with something similar to this:

    rake resque:work QUEUE=low,normal,* &
    rake resque:work QUEUE=normal,*     &
    rake resque:work QUEUE=normal,*     &
    rake resque:work QUEUE=*            &
    rake resque:work QUEUE=*            &

`worker` and `worker_pool` accept a hash of options that will be passed to `Resqued::Worker`. The supported options are:

* `:interval` - The interval to pass to `Resque::Worker#run`.

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
    queue 'low', '20%'
    queue 'normal', 4
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

In this example, a Rails application is being set up with 7 workers:
* high
* low (interval = 30)
* low, normal, * (interval = 1)
* normal, * (interval = 1)
* normal, * (interval = 1)
* normal, * (interval = 1)
* * (interval = 1)

## Multiple configurations

If your app has several work machines, each with the same application code but different sets of workers, you might want to have a shared config file for the `before_fork` and `after_fork` blocks. You can pass in several config files, and resqued will act as if you concatenated them.

    $ resqued config/shared.rb config/pool-a.rb
    $ resqued config/shared.rb config/pool-b.rb

## See also

For information about how resqued works, see the [documentation](docs/).
