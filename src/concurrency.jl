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
  channel::Base.Channel{Any}
end

@forward Channel.channel (Base.isready, Base.close)

Channel(src::Thread, dst::Thread, size::Real = Inf) = Channel(src, dst, Base.Channel{Any}(size))

Graphs.src(ch::Channel) = ch.src
Graphs.dst(ch::Channel) = ch.dst

const ThreadGraph = PropertyGraph{Int,SimpleDiGraph{Int},Thread,Channel}

function thread_graph()
  g = ThreadGraph()
  th = Thread(current_task(), g)
  add_vertex!(g, th)
  finalizer(g) do x
    for dst in vertex_properties(x)
      @async shutdown(th, dst)
    end
  end
end

thread(g::ThreadGraph, idx::Integer) = property(g, convert(Int, idx))
threads(g::ThreadGraph) = vertex_properties(g)
function channel(src::Thread, dst::Thread)
  g = thread_graph(src)
  add_edge!(g, src, dst)
  property(g, src, dst)
end

Thread(task::Task, g::ThreadGraph) = set_task(Thread(g), task)

function Thread(f, g::ThreadGraph)
  th = Thread(g)
  set_task(th, Threads.@spawn f(th))
end

thread_graph(th::Thread) = th.g::ThreadGraph
thread_graph(ch::Channel) = thread_graph(ch.src)

function incoming_channels(th::Thread)
  g = thread_graph(th)
  Channel[channel(thread(g, src), th) for src in inneighbors(g, index(g, th))]
end

function outgoing_channels(th::Thread)
  g = thread_graph(th)
  Channel[channel(th, thread(g, dst)) for dst in outneighbors(g, index(g, th))]
end

"Send a message `v` from the current thread to `th`."
send(th::Thread, v) = send(current_thread(thread_graph(th)), th, v)
"Send a message `v` from `src` to `dst`."
send(src::Thread, dst::Thread, v) = send(channel(src, dst), v)
send(ch::Channel, v) = put!(ch.channel, v)

"Receive a message on the current thread from `th`."
receive(th::Thread) = receive(current_thread(thread_graph(th)), th)
"Receive a message on `src` from `dst`."
receive(src::Thread, dst::Thread) = receive(channel(dst, src))
receive(ch::Channel) = take!(ch.channel)

function shutdown(src::Thread, dst::Thread)
  isdefined(dst.taskref, 1) || return true
  task = dst.taskref[]
  !istaskstarted(task) && return true
  istaskdone(task) && return true
  cancel(src, dst)
end
shutdown(dst::Thread) = shutdown(current_thread(thread_graph(dst)), dst)

struct Cancel end

function cancel(src::Thread, dst::Thread; timeout = 2)
  task = dst.taskref[]
  send(src, dst, Cancel())
  wait_timeout(task, timeout)
end
cancel(th::Thread; timeout = 2) = cancel(current_thread(thread_graph(th)), th; timeout)

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
  args::Any
  kwargs::Any
  src::Thread
  dst::Thread
  continuation::Any
end

Command(f, dst, args...; src = current_thread(thread_graph(dst)), continuation = nothing, kwargs...) = Command(uuid(), f, args, kwargs, src, dst, continuation)

function current_thread(g::ThreadGraph)
  ths = threads(g)
  task = current_task()
  current_th_idx = findfirst(x -> isdefined(x.taskref, 1) && x.taskref[] == task, ths)
  isnothing(current_th_idx) && error("The current task has not been added to the thread graph.")
  ths[current_th_idx]
end

function execute(command::Command)
  !isnothing(command.continuation) && insert!(command.src.pending, command.uuid, command.src)
  send(command.src, command.dst, command)
end

function collect_messages(th::Thread)
  any(collect_messages(th, ch) for ch in incoming_channels(th))
end

function collect_messages(th::Thread, ch::Channel)
  while isready(ch)
    item = receive(ch)
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

function process_message(::Thread, command::Command)
  ret = Base.invokelatest(command.f, command.args...; command.kwargs...)
  if !isnothing(command.continuation)
    send(command.dst, ReturnedValue(command.uuid, ret))
  end
end

function process_message(th::Thread, returned::ReturnedValue)
  command = th.pending[returned.uuid]::Command
  delete!(th.pending, returned.uuid)
  command.continuation(returned.value)
end

process_message(::Thread, cancel::Cancel) = cancel

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
  for ch in incoming_channels(th)
    collect_messages(th, ch)
    close(ch)
  end

  g = thread_graph(th)
  rem_vertex!(g, th)
end
