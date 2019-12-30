before_fork do
  raise "boom"
end

worker "test"
