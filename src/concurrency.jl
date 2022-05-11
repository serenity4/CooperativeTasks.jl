struct Thread
  """
  Reference to the task being executed.

  This should never be changed beyond initialization. It has been made a `Ref` so that
  the function attached to the thread can take the thread itself as argument.
  """
  taskref::RefValue{Task}
  g::PropertyGraph
  pending::Dictionary{UUID,Any}
  function Thread(g::PropertyGraph)
    th = new(Ref{Task}(), g, Dictionary())
    add_vertex!(g, th)
    th
  end
end

Base.show(io::IO, th::Thread) = print(io, "Thread(", th.taskref, ')')

function set_task(th::Thread, task::Task)
  !isdefined(th.taskref, 1) || error("Replacing an existing task is not allowed.")
  th.taskref[] = task
  th
end

"""
Directed communication link from `src` to `dst`.
`send` and `recv` are to be interpreted from the perspective of `src`.
"""
struct Channel
  src::Thread
  dst::Thread
  send::Base.Channel{Any}
  recv::Base.Channel{Any}
end

Channel(src, dst, size = Inf) = Channel(src, dst, Base.Channel{Any}(size), Base.Channel{Any}(size))
function Base.close(ch::Channel)
  close(ch.send)
  close(ch.recv)
end

Graphs.src(ch::Channel) = ch.src
Graphs.dst(ch::Channel) = ch.dst

const ThreadGraph = PropertyGraph{Int,SimpleGraph{Int},Thread,Channel}

function thread_graph()
  g = ThreadGraph()
  add_vertex!(g, Thread(current_task(), g))
  g
end
thread(g::ThreadGraph, idx::Integer) = property(g, convert(Int, idx))
threads(g::ThreadGraph) = vertex_properties(g)
channel(src::Thread, dst::Thread) = property(thread_graph(src), src, dst)

Thread(task::Task, g::ThreadGraph) = set_task(Thread(g), task)

function Thread(f, g::ThreadGraph)
  th = Thread(g)
  set_task(th, Threads.@spawn f(th))
end

thread_graph(th::Thread) = th.g::ThreadGraph
thread_graph(ch::Channel) = thread_graph(ch.src)

function channels(th::Thread)
  g = thread_graph(th)
  Channel[channel(thread(g, src), th) for src in inneighbors(g, index(g, th))]
end

send(dst::Thread, v) = send(current_thread(), dst, v)

function send(src::Thread, dst::Thread, v)
  g = thread_graph(src)
  has_edge(g, src, dst) || error("No communication channel established between $src and $dst.")
  put!(channel(src, dst).send, v)
end

receive(src::Thread) = receive(src, current_thread())

function receive(src::Thread, dst::Thread)
  g = thread_graph(src)
  has_edge(g, src, dst) || error("No communication channel established between $src and $dst.")
  take!(Channel(g, src, dst))
end

function shutdown(src::Thread, dst::Thread)
  g = thread_graph(src)
  isdefined(th.taskref) || return true
  task = th.taskref[]
  !istaskstarted(task) && return true
  istaskdone(task) && return true
  cancel(g, src, dst)
end

struct Cancel end

function cancel(src::Thread, dst::Thread; timeout = 2)
  task = dst.taskref[]
  send(src, dst, Cancel())
  wait_timeout(task, timeout)
end

function interrupt(task::Task, timeout::Real)
  Base.throwto(task, InterruptException())
  wait_timeout(task, timeout)
end

function wait_timeout(task::Task, timeout::Real)
  t0 = time()
  while time() - t0 < timeout
    istaskdone(task) && return true
    sleep(0.01)
  end
  istaskdone(task)
end

"""
Execute `ret = f()` on a dst thread, optionally executing `continuation(ret)` from the source thread.

First, the command is registered on a source thread with a corresponding UUID. Then, it is sent to the dst thread for execution, which will send back the value associated with this UUID. When the source thread next collects new messages, it will run `continuation` with the returned value.
"""
struct Command
  uuid::UUID
  f::Any
  src::Thread
  dst::Thread
  continuation::Any
end

Command(f, dst; src = current_thread(), continuation = nothing) = Command(uuid(), f, src, dst, continuation)

function current_thread(g::ThreadGraph)
  ths = threads(g)
  task = current_task()
  current_th_idx = findfirst(x -> isdefined(x.taskref, 1) && x.taskref[] == task, ths)
  isnothing(current_th_idx) && error("The current task has not been added to the thread graph.")
  ths[current_th_idx]
end

function execute(command::Command)
  !isnothing(command.continuation) && insert!(th.pending, id, command.src)
  send(command.src, command.dst, command)
end

function collect_messages(th::Thread)
  any(collect_messages(th, ch) for ch in channels(th))
end

function collect_messages(th::Thread, ch::Channel)
  while isready(ch.send)
    item = take!(ch.send)
    item === Cancel() && return true
    process_message(th, item)
  end
  false
end

struct ReturnedValue
  uuid::UUID
  value::Any
end

process_message(::Thread, message::Any) = error("No processing was specified for messages with type $(typeof(message)).")

function process_message(th::Thread, command::Command)
  ret = command.f()
  if !isnothing(command.continuation)
    send(th, command.dst, ReturnedValue(command.uuid, ret))
  end
end

function process_message(th::Thread, returned::ReturnedValue)
  command = th.pending[returned.uuid]::Command
  delete!(th.pending, returned.uuid)
  command.continuation(returned.value)
end

process_message(th::Thread, cancel::Cancel) = cancel

abstract type ExecutionMode end

struct Activity
  time::Float64
  duration::Float64
end

mutable struct ExecutionState
  recent_activity::Vector{Activity}
end
ExecutionState() = ExecutionState([])

function record_activity(f, th::Thread, state::ExecutionState)
  t = time()
  timed = @timed try
    f(th)
  catch e
    e
  end
  length(state.recent_activity) ≥ 100 && popfirst!(state.recent_activity)
  push!(state.recent_activity, Activity(t, timed.time))
  timed.value
end

struct LoopExecution <: ExecutionMode
  period::Union{Nothing,Float64}
  state::ExecutionState
end
LoopExecution(period) = LoopExecution(period, ExecutionState())

function (exec::LoopExecution)(f)
  function _exec(th::Thread)
    interrupted = false
    cancelled = false
    while !cancelled
      t0 = time()
      ret = f(th)

      ret === 0 && break
      if ret isa InterruptException
        interrupted = true
        break
      end

      ret isa Exception && propagate_error(th, ret)

      Δt = time() - t0
      # TODO: record acitivity when collecting messages.
      # Maybe this should be handled by the thread itself.
      cancelled = collect_messages(th)
      cancelled && break
      while Δt < exec.period || isnothing(exec.period)
        cancelled = collect_messages(th)
        cancelled && break
        Δt = time() - t0
        if Δt - exec.period ≥ 0.001 && !has_activity(exec)
          sleep(Δt - exec.period)
        end
        Δt = time() - t0
      end
    end

    cancelled && return
    interrupted && return interrupt_parent(th)
    cleanup(th)
  end
end

function has_activity(exec::ExecutionMode)
  isempty(exec.state.recent_activity) && return false
  time() - last(exec.state.recent_activity).time < 3exec.period
end

# TODO: Implement a cancellation mechanism.
propagate_error(th::Thread, exc::Exception) = rethrow(exc)
interrupt_parent(th::Thread) = nothing

function cleanup(th::Thread)
  g = thread_graph(th)

  for ch in channels(th)
    collect_messages(th, ch)
    close(ch)
  end

  rem_vertex!(g, th)
end
