# Inter-Process Communication

## Master / Listener

## Listener / Worker

There is no direct communication between the Listener and the Worker.

## Daemon / Master

The Daemon process opens a pipe. When the Master process starts, it writes its pid to the pipe, and the daemon reads it and exits. If the read fails, the daemon exits with an error status.

## `self_pipe`

Each process has a `self_pipe` that it uses as a sleep timer. When the process has no work to do, it performs an `IO.select` on the pipe. If a signal is received, the signal is recorded and a `'.'` is written to the pipe, which causes `IO.select` to finish. This helps avoid race conditions between the main loop and signal handling blocks.
