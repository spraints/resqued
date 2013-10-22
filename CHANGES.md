Starting with version 0.6.1, resqued uses semantic versioning to indicate incompatibilities between the master process, listener process, and configuration.

0.7.0
-----

* Configuration was changed. In a worker pool, you can no longer specify the number of workers in a bare argument, e.g. `queue "queue_name", "50%"`. Now, you must use a hash to define how many workers work on a given queue, e.g. `queue "queue_name", :percent => 50`. Additionally, you can provide several queues in one call to queue, e.g. `queue "a", "b", "c"`.

* A message was added to indicate that a listener has started. This lets the master wait until the new listener is fully booted before it kills the old listener.

* The master advertises its version to the listener. This will make it easier to update the protocol between the master and listener in a backward-compatible way.
