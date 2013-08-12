module Resqued
  module Pidfile
    def with_pidfile(filename)
      yield
    end
  end
end
