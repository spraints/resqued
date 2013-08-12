require 'socket'

def main
  #parent, child = Socket.socketpair(:UNIX, :DGRAM, 0)
  parent, child = UNIXSocket.pair
  if fork
    puts "Control-\\ makes us talk. (Third time exits.)"
    child.close
    trap(:CHLD) { wait_for_child('signal', Process::WNOHANG) }
    n = 0
    trap(:QUIT) { parent.send("hi from #{$$}!", 0) ; n += 1 }
    while n < 3
      if IO.select([parent], nil, nil, 1.0)
        puts parent.recv(100)
      end
    end
    parent.send("exit", 0)
    wait_for_child('normal')
  else
    parent.close
    be_a_child(child)
  end
end

def be_a_child(child)
  trap(:QUIT) { } # ^\ sends QUIT to all children of the foreground process. DUMB
  loop do
    if IO.select([child], nil, nil, 60.0)
      s = child.recv(100)
      return if s == 'exit'
      child.send "you said, #{s.inspect}. (#$$)", 0
    end
  end
end

def wait_for_child(reason, waitpid_flags=0)
  res = Process.waitpid2(waitpid_flags)
  p [$$, reason, res]
rescue Errno::ECHILD => e
  puts "[#$$] #{e} (#{reason})"
end

if ARGV[0] == 'child'
  fd = ARGV[1].to_i - 1
  p [fd, f = IO.for_fd(ARGV[1].to_i, 'w')]
  puts "I AM FAKE"
  writer(f)
else
  main
end
