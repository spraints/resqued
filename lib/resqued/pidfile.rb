module Resqued
  module Pidfile
    def with_pidfile(filename)
      write_pidfile(filename) if filename
      yield
    ensure
      remove_pidfile(filename) if filename
    end

    def write_pidfile(filename)
      pf =
        begin
          tmp = "#{filename}.#{rand}.#{$$}"
          File.open(tmp, File::RDWR | File::CREAT | File::EXCL, 0644)
        rescue Errno::EEXIST
          retry
        end
      pf.syswrite("#{$$}\n")
      File.rename(pf.path, filename)
      pf.close
    end

    def remove_pidfile(filename)
      (File.read(filename).to_i == $$) and File.unlink(filename) rescue nil
    end
  end
end
