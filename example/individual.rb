# Run like this:
#
#     $ resqued example/minimal.rb

before_fork do
  host = ENV["REDIS_HOST"] || "localhost"
  port = ENV["REDIS_PORT"] || 6379
  Resque.redis = Redis.new(host: host, port: port)
end

worker "resqued-example-queue"
