# Inter-Process Communication

## Master / Listener

`Resqued::ListenerProxy` opens a Unix domain socket to communicate between the Master and Listener processes. Resqued uses a socket (instead of a pipe) because the socket is bidirectional and a socket can be reopened after `exec`.

The Listener process sends information about the lifecycle of worker processes that it controls. When a worker starts, the listener writes `"+#{pid},#{queues}\n"`, e.g. `"+21234,important,*\n"`. When a worker exits, the listener writes `"-#{pid}\n"`.

The Master process broadcasts dead worker PIDs to all running listeners. This allows a new listener to wait for old workers to exit before starting their replacements. These messages are just the pid, `"#{pid}\n"`, e.g. `"21234\n"`.

*Does the dead worker broadcast need to go to all listeners? Or just the current listener?*

## Listener / Worker

There is no direct communication between the Listener and the Worker.

## Daemon / Master

The Daemon process opens a pipe. When the Master process starts, it writes its pid to the pipe, and the daemon reads it and exits. If the read fails, the daemon exits with an error status.

## `self_pipe`

Each process has a `self_pipe` that it uses as a sleep timer. When the process has no work to do, it performs an `IO.select` on the pipe. If a signal is received, the signal is recorded and a `'.'` is written to the pipe, which causes `IO.select` to finish. This helps avoid race conditions between the main loop and signal handling blocks.
