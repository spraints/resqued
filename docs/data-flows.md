# IPC data flows

A number of pipes are opened for process coordination.

# master -> master (`Resqorn::Master#self_pipe`)

This pipe is used to put master to sleep in a reliably wake-able way.
When there is nothing for master to do, it calls `IO.select` with a long
timeout. If a signal comes in, write to `self_pipe` so that the select
call finishes.

# listener -> master

When a listener starts up a worker, it tells the master process about it.
When a listener sees a worker die, it tells the master process about it.

This allows the master process to track the number of workers for a given
queue, so that other listeners know how many workers they should not
immediately start.

# master -> listener

When a worker dies, the master hears about it. Master tells the current
listener about the dead worker, so that it can spin up a new worker in its
place.
