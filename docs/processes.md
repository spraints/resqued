# Process types in resqued

Resqued runs the following processes, named after the main class that runs in them:

* `Resqued::Daemon` is the first process run, if the `-D` flag is provided. It runs until the Master process is started.
* `Resqued::Master` is the main process. This process does not restart, so it is somewhat minimal, and should work with different versions of the Listener.
* `Resqued::Listener` is started by the Master. A new Listener is started each time the configuration or application is reloaded (on SIGHUP). It manages the pool of workers.
* `Resqued::Worker` is started by the Listener, once for each worker.

In normal operation, there are one Master, one Listener, and several Worker processes.

When the workers are idle:

```
-+= 77038 burke resqued master [gen 1] [1 running] config/resqued.rb
 \-+- 77208 burke resqued listener #1 6/6/6 [running] config/resqued.rb
   |--- 77492 burke resque-1.24.1: Waiting for import_high
   |--- 77493 burke resque-1.24.1: Waiting for import_high
   |--- 77494 burke resque-1.24.1: Waiting for important,import_low
   |--- 77495 burke resque-1.24.1: Waiting for important,import_low
   |--- 77496 burke resque-1.24.1: Waiting for normal
   \--- 77497 burke resque-1.24.1: Waiting for normal
```

When the workers are working:

```
-+= 77038 burke resqued master [gen 1] [1 running] config/resqued.rb
 \-+- 51166 burke resqued listener #1 6/6/6 [running] config/resqued.rb
   |-+- 51638 burke resque-1.24.1: Forked 78947 at 1377103813
   | \--- 78947 burke SlowJob::ImportHigh 23 seconds remaining...
   |-+- 51639 burke resque-1.24.1: Forked 78948 at 1377103813
   | \--- 78948 burke SlowJob::ImportHigh 23 seconds remaining...
   |-+- 51642 burke resque-1.24.1: Forked 78950 at 1377103813
   | \--- 78950 burke SlowJob::Normal 4 seconds remaining...
   |-+- 51643 burke resque-1.24.1: Forked 78949 at 1377103813
   | \--- 78949 burke SlowJob::Normal 4 seconds remaining...
   |-+- 79907 burke resque-1.24.1: Forked 79920 at 1377103819
   | \--- 79920 burke SlowJob::ImportLow 29 seconds remaining...
   \-+- 79908 burke resque-1.24.1: Forked 79921 at 1377103819
     \--- 79921 burke SlowJob::ImportLow 29 seconds remaining...
```

During restart, there should be no more workers than the configuration specifies, but they may be spread out across several listeners. As the workers finish working on the old listener, they will exit and start up on the new listener. When the old listener has no more workers, it exits.

```
-+= 51121 burke resqued master [gen 2] [2 running] config/resqued.rb
 |-+- 51166 burke resqued listener #1 4/4/6 [shutdown] config/resqued.rb
 | |-+- 51638 burke resque-1.24.1: Forked 78947 at 1377103813
 | | \--- 78947 burke SlowJob::ImportHigh 23 seconds remaining...
 | |-+- 51639 burke resque-1.24.1: Forked 78948 at 1377103813
 | | \--- 78948 burke SlowJob::ImportHigh 23 seconds remaining...
 | |-+- 51642 burke resque-1.24.1: Forked 78950 at 1377103813
 | | \--- 78950 burke SlowJob::Normal 4 seconds remaining...
 | \-+- 51643 burke resque-1.24.1: Forked 78949 at 1377103813
 |   \--- 78949 burke SlowJob::Normal 4 seconds remaining...
 \-+- 79528 burke resqued listener #2 2/6/6 [running] config/resqued.rb
   |-+- 79907 burke resque-1.24.1: Forked 79920 at 1377103819
   | \--- 79920 burke SlowJob::ImportLow 29 seconds remaining...
   \-+- 79908 burke resque-1.24.1: Forked 79921 at 1377103819
     \--- 79921 burke SlowJob::ImportLow 29 seconds remaining...
```

## Spawning

The Daemon process starts the Master process with a double-fork, the normal daemonization process.

The Master process starts the Listener process with a fork+exec. `bin/resqued-listener` is the process that is executed. Doing a full exec on the listener allows it to load any application changes, including changes to the `Gemfile`, without any special code. In order to keep the exec interface flexible, all initialization data is passed to the listener from the master via environment variables. This information is minimal, and includes the location of the config file and the status of other workers.

The Listener process loads the application configuration (the `before_fork` block in the configuration file) before starting any workers. Worker processes are started by forking, and starting the Resque::Worker run loop.

In the event that a Listener or Worker exits quickly and unexpectedly, resqued will not immediately restart the process.
