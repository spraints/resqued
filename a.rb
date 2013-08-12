def main
  r,w = IO.pipe
  if fork
    r.close
    parent(w)
    res = Process.waitpid2
    p [$$, res]
  else
    w.close
    child(r)
  end
end

def parent(w)
  w.puts "#$$ I AM PARENT"
  w.close
end

def child(r)
  puts "#$$ reads: #{r.readline}"
end

main
