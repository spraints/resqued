module Resqued
  module Logging
    def log(message)
      puts "[#{$$} #{Time.now.strftime('%H:%M:%S')}] #{message}"
    end
  end
end
