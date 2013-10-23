after_fork { raise 'boom' }
worker "test"
