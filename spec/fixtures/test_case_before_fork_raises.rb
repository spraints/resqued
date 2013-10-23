before_fork { raise 'boom' }
worker "test"
