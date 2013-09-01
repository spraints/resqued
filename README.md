# resqued - a long-running daemon for resque workers.

Resqued is a multi-process daemon that controls and monitors a pool of resque workers. It works well with slow jobs and continuous delivery.

## Installation

Install by adding resqued to your Gemfile

    gem 'resqued'

Run resqued with a config file, like this:

    resqued config/resqued.rb

Or like this to daemonize it:

    resqued -p tmp/pids/resqued-master.pid -D config/resqued.rb

## Configuration

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

## See also

For information about how resqued works, see the [documentation](docs/).
