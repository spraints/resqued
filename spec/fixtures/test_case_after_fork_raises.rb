after_fork { raise 'boom' }
worker_pool 100
queue 'test'
