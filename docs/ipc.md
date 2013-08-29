# Inter-process Communication and Signals in Resqued

Resqued is a multi-process daemon that controls and monitors a pool of resque workers. To keep the right number of workers running, including while reloading, resqued uses pipes and sockets to communicate status.

## Process types

Resqued runs the following processes, named after the main class that runs in them:

* `Resqued::Daemon` is the first process run, if the `-D` flag is provided. It runs until the Master process is started.
* `Resqued::Master` is the main process. This process does not restart, so it is somewhat minimal, and should work with different versions of the Listener.
* `Resqued::Listener` is started by the Master. A new Listener is started each time the configuration or application is reloaded (on SIGHUP). It manages the pool of workers.
* `Resqued::Worker` is started by the Listener, once for each worker.

## Signals

### Daemon

### Master

### Listener

### Worker


## IPC

### Daemon / Master

### Master / Listener

### Listener / Worker
