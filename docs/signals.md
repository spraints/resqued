# Signals in resqued

Signals control restart, reload, and shutdown in resqued. This file documents the signals that resqued's processes handle. You should normally only send signals to the Master process.

## Master

The Master process handles several signals.

* `HUP`: Kill the listener with `SIGQUIT` and start a new listener.
* `QUIT`, `INT`, or `TERM`: Kill the listener with the same signal and wait for it to exit.
* `CHLD`: Clean up any listeners that have exited. If the current listener exited

## Listener

The Listener process only handles the `QUIT` signal. When it receives `SIGQUIT`, it goes into shutdown mode. It sends `SIGQUIT` to all of its workers. When all workers have exited, the Listener process exits.

## Worker

The Worker process uses resque's signal handling. Resque 1.23.0 handles the following signals:

* `TERM`: Shutdown immediately, stop processing jobs.
* `INT`:  Shutdown immediately, stop processing jobs.
* `QUIT`: Shutdown after the current job has finished processing.
* `USR1`: Kill the forked child immediately, continue processing jobs.
* `USR2`: Don't process any new jobs
* `CONT`: Start processing jobs again after a USR2
