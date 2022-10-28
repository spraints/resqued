after_exit do
  raise "boom"
end

worker "test"
