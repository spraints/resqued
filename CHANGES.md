Starting with version 0.6.1, resqued uses semantic versioning to indicate incompatibilities between the master process, listener process, and configuration.

v0.13.0
-------
* Re-exec on SIGUSR1 instead of SIGHUP. There should be no compatibility
  problem between 0.12 and 0.13, but the behavior will be different. If you
  start 0.12 and then upgrade to 0.13, resqued will re-exec on HUP until it
  hits 0.13. If you downgrade to 0.12, resqued's master will stay at 0.13 even
  though the listener changes to 0.12; `kill -USR1 $pid` to get the 0.13 master
  to roll back to 0.12, too. Note: take care not to `kill -USR1` a 0.12
  resqued, as that will cause it to shut down. (#71)

v0.12.4
-------
* Add support for redis client gem version 5. (#70)

v0.12.3
-------
* Add `after_exit` that provides a `WorkerSummary` about each exited worker.

v0.12.2
-------
* Added lifecycle hook for container runtimes. (#67)

v0.12.1
-------
* Fixed Resqued::TestCase. v0.12.0 introduced a regression that stopped
  `after_fork` blocks from being tested. This fixes some other problems in CI,
  too. (#66)

v0.12.0
-------
* Drop "resque" as a dependency. Apps that use Resqued with a different job
  system will no longer also have a transitive dependency on resque. Apps that
  rely on resqued's resque dependency will need to add `gem "resque"` to their
  `Gemfile`. (#65)

v0.11.2
-------
* Add compatibility with Ruby 3.1. (#63)
* Switch to GitHub Actions for CI. (#64)

v0.11.1
-------
* Fix a crash during shutdown. (#62)

v0.11.0
-------
* Ignore SIGHUP in Listener and Worker processes. (#61)

v0.10.3
-------
* Fix a timing related crash during reload. (#60)

v0.10.2
-------
* Shut down cleanly even if there are other stray child processes of the master. (#59)

v0.10.1
-------
* Avoid deadlock if a listener stops responding. (#58)
* When using 'percent' for a queue in a worker pool, always assign at least one worker. (#57)

v0.10.0
-------
* Master process restarts itself (#51), so that it doesn't continue running stale code indefinitely. This will help with the rollout process when changes like #50 are introduced, so that the master process will catch up. The risk of this is that the master process might not be able to be restarted, which would lead to it crashing. The mostly likely way for that to happen is if you try to roll back your version of resqued to 0.9.0 or earlier. If you need to do that, ensure that your process monitor (systemd, god, etc.) is able to restart the master process. You can disable the new behavior by passing `--no-exec-on-hup`.
* Added rubocop. (#52)
* Changed supported (read: tested in CI) ruby versions from [2.0 .. 2.3] to [2.3 .. 2.6].

v0.9.0
------
* Avoid Errno::E2BIG on SIGHUP when there are lots of workers and lots of queues per worker. (#50) This changes the format of an env var that master passes to listener. Old and new versions won't crash, but they won't be able to communicate about currenly running workers.

v0.8.6
------
* Add compatibility for redis 4.0.

v0.8.5
------
* Accept a custom proc to create the worker object.

v0.8.4
------
* Use `Integer` in place of `Fixnum`, when it's available.

v0.8.3
------
* Add a "fast-exit" mode (#44)

v0.8.2
------
* Detach more completely (#43)
* Fix for ECONNRESET (#44)

v0.8.1
------
* Fix an error on fast SIGHUP (#42, @asceth)

v0.8.0
------

* Make proclines work again. (#40) (This introduces a new argument to the re-exec of resqued. Old masters (0.7.x) will be able to start new listeners (0.8.x), but new masters (0.8.x) will not be able to start <0.8 listeners.)

v0.7.14
-------

* Restart `SIGKILL`ed workers. (#39)

v0.7.13
-------

* Support for symlinks in production environments. (#36)

v0.7.12
-------

* Fix EXIT trap. (#34)
* Document resque compatibility. (#20)

v0.7.11
-------

* Show worker count in more proclines. (#32)

v0.7.10
-------

* Support require_relative in config files. (#31)

0.7.9
-----

* Add the app's current version to the procline. (#30)

0.7.8
-----

* Avoid losing track of workers (#21, #29)

0.7.7
-----

* Open source: set new gem home page, run CI on travis, etc.
* Rewrite Resqued::TestCase.

0.7.6
-----

* Adds more logging.

0.7.4
-----

* Better logging with (Mono)Logger!
* Unregister resqued's signal handlers before running a resque worker.
* Report the number of workers spinning down.

0.7.3
-----

broken

0.7.2
-----

* Ensure that no stale log file handles exists after a SIGHUP.

0.7.1
-----

* Adds some `assert_resqued` test helpers.

0.7.0
-----

* Configuration was changed. In a worker pool, you can no longer specify the number of workers in a bare argument, e.g. `queue "queue_name", "50%"`. Now, you must use a hash to define how many workers work on a given queue, e.g. `queue "queue_name", :percent => 50`. Additionally, you can provide several queues in one call to queue, e.g. `queue "a", "b", "c"`.

* A message was added to indicate that a listener has started. This lets the master wait until the new listener is fully booted before it kills the old listener.

* The master advertises its version to the listener. This will make it easier to update the protocol between the master and listener in a backward-compatible way.
