# Push a job:
#   bundle exec ruby example/sleepy.rb
# Work queued jobs:
#   bundle exec resqued example/sleepy.rb
QUEUE = "sleepy-queue"

if $0 == __FILE__
  require "resque"
  host = ENV["REDIS_HOST"] || "localhost"
  port = ENV["REDIS_PORT"] || 6379
  Resque.redis = Redis.new(host: host, port: port)
  puts "Pushing a #{QUEUE} job!"
  Resque.push(QUEUE, class: "SleepyJob", :args => [])
  exit 0
end

before_fork do
  host = ENV["REDIS_HOST"] || "localhost"
  port = ENV["REDIS_PORT"] || 6379
  Resque.redis = Redis.new(host: host, port: port)
end

after_fork do
  require_relative "./sleepy_job"
end

worker QUEUE
