struct Thread
  task::Task
  Thread(f) = new(Task(f))
end

struct Channel
  send::Base.Channel{Any}
  recv::Base.Channel{Any}
end

Channel(size = Inf) = Channel(Base.Channel{Any}(size), Base.Channel{Any}(size))

const ThreadGraph = PropertyGraph{Int,SimpleGraph{Int},Thread,Channel}

Channel(g::ThreadGraph, src::Thread, dst::Thread) = property(g, Edge(index(g, src), index(g, dst)))

function send(g::ThreadGraph, src::Thread, dst::Thread, v)
  put!(Channel(g, src, dst).send, v)
end

function receive(g::ThreadGraph, src::Thread, dst::Thread)
  take!(Channel(g, src, dst))
end
