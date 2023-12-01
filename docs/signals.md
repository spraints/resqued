# Signals in resqued

Signals control restart, reload, and shutdown in resqued. This file documents the signals that resqued's processes handle. You should normally only send signals to the Master process.

Here is a summary of how signals get passed between resqued's processes:

```
                  master    listener    worker
                  ------    --------    ------
restart            HUP   -> QUIT     -> QUIT
reexec master     USR1   -> QUIT     -> QUIT
exit now           INT   ->  INT     ->  INT
exit now          TERM   -> TERM     -> TERM
exit when ready   QUIT   -> QUIT     -> QUIT
pause             USR2   -> QUIT     -> QUIT
unpause           CONT   -> (start)
unpause           CONT   -> CONT     -> CONT
```

Read on for more information about what the signals mean.

## Master

The Master process handles several signals.

* `HUP`: Start a new listener. After it boots, kill the previous listener with `SIGQUIT`.
* `USR1`: Re-exec the master process, preserving the current state. Also exec a new listener.
* `USR2`: Pause processing. Kills the current listener, and does not start a replacement.
* `CONT`: Resume processing. If there is no listener, start one. If there is a listener, send it `SIGCONT`.
* `QUIT`, `INT`, or `TERM`: Kill the listener with the same signal and wait for it to exit. If `--fast-exit` was specified, the master exits immediately without waiting for the listener to exit.
* `CHLD`: Clean up any listeners that have exited. If the current listener exited

## Listener

The Listener process forwards `SIGCONT` to all of its workers.

The Listener process handles `SIGINT`, `SIGTERM`, and `SIGQUIT`. When it receives one of these signals, it goes into shutdown mode. It sends the received signal to all of its workers. When all workers have exited, the Listener process exits.

The Listener process handles `SIGHUP` and does nothing. This makes it easier to reload resqued in a docker container, since many container platforms will send a requested signal to all processes in the container.

## Worker

The Worker process uses resque's signal handling. Resque 1.23.0 handles the following signals:

* `TERM`: Shutdown immediately, stop processing jobs.
* `INT`:  Shutdown immediately, stop processing jobs.
* `QUIT`: Shutdown after the current job has finished processing.
* `USR1`: Kill the forked child immediately, continue processing jobs.
* `USR2`: Don't process any new jobs
* `CONT`: Start processing jobs again after a USR2

Resqued leaves a handler for `HUP` in place that does nothing. This makes it easier to reload resqued in a docker container, since many container platforms will send a requested signal to all processes in the container.
