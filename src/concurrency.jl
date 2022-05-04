struct Thread
  taskref::RefValue{Task}
  Thread() = new(Ref{Task}())
  function Thread(f)
    th = Thread()
    th.taskref[] = Task(() -> f(th))
    th
  end
end

struct Channel
  src::Thread
  dst::Thread
  send::Base.Channel{Any}
  recv::Base.Channel{Any}
end

Channel(src, dst, size = Inf) = Channel(src, dst, Base.Channel{Any}(size), Base.Channel{Any}(size))
Graphs.src(ch::Channel) = ch.src
Graphs.dst(ch::Channel) = ch.dst

const ThreadGraph = PropertyGraph{Int,SimpleGraph{Int},Thread,Channel}

Channel(g::ThreadGraph, src::Thread, dst::Thread) = property(g, src, dst)

function send(g::ThreadGraph, src::Thread, dst::Thread, v)
  has_edge(g, src, dst) || error("No communication channel established between $src and $dst.")
  put!(Channel(g, src, dst).send, v)
end

function receive(g::ThreadGraph, src::Thread, dst::Thread)
  has_edge(g, src, dst) || error("No communication channel established between $src and $dst.")
  take!(Channel(g, src, dst))
end

function shutdown(g::ThreadGraph, src::Thread, dst::Thread; interrupt = false)
  isdefined(th.taskref) || return true
  task = th.taskref[]
  !istaskstarted(task) && return true
  (istaskdone(task) || istaskfailed(task)) && return true
  cancel(g, src, dst; interrupt)
end

function cancel(g::ThreadGraph, src::Thread, dst::Thread; interrupt = true)
  cancel(dst, Channel(g, src, dst); interrupt)
end

function cancel(th::Thread, ch::Channel; timeout = 2, interrupt = true, interrupt_timeout = 1)
  task = th.taskref[]
  put!(ch, CancellationToken())
  wait_timeout(task, timeout) && return true
  !interrupt && return false
  ConcurrencyGraph.interrupt(task, interrupt_timeout)
end

function interrupt(task::Task, timeout::Real)
  Base.throwto(task, InterruptException())
  wait_timeout(task, timeout)
end

function wait_timeout(task::Task, timeout::Real)
  t0 = time()
  while time() - t0 < timeout
    (istaskdone(task) || istaskfailed(task)) && return true
    sleep(0.01)
  end
  istaskdone(task) || istaskfailed(task)
end
