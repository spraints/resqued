after_fork do
  raise "boom"
end

worker_pool 100
queue "test"
