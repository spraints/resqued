class SleepyJob
  def self.perform
    puts "#{object_id} START sleep 30"
    sleep 30
    puts "#{object_id} STOP sleep 30"
  end
end
