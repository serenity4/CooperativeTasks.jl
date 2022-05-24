"""
Execute `ret = f()` on a task, optionally executing `continuation(ret)` from the task the message has been sent from.

First, the command is registered on a source task with a corresponding UUID. Then, as part of a message, it is sent to the destination task for execution, which will send back the value associated with this UUID if any continuation has been provided. If so, when the source task next collects new messages, it will run `continuation` with the returned value.
"""
struct Command
  f::Any
  args::Any
  kwargs::Any
  continuation::Any
  register_future::Bool
end

Command(f, args...; continuation = nothing, register_future::Bool = false, kwargs...) = Command(f, args, kwargs, continuation, register_future)

function send(task::Task, command::Message{Command})
  !isnothing(command.payload.continuation) && insert!(pending_messages(), command.uuid, command)
  Base.@invoke send(task::Task, command::Message)
  command.payload.register_future ? Future(command.uuid, task) : nothing
end

function call(f, task::Task, args...; critical = false, kwargs...)
  send(task, Command(f, args...; kwargs..., register_future = true); critical)
end

function execute(f, task::Task, args...; critical = false, kwargs...)
  send(task, Command(f, args...; kwargs...); critical)
end

function process_message(command::Message{Command})
  (; payload) = command
  ret = Base.invokelatest(payload.f, payload.args...; payload.kwargs...)
  if !isnothing(payload.continuation) || payload.register_future
    send(command.from, Message(ReturnedValue(ret, payload.register_future), command.uuid; command.critical))
  end
end

struct ReturnedValue
  value::Any
  register_future::Bool
end

function process_message(m::Message{ReturnedValue})
  messages = pending_messages()
  command = get(messages, m.uuid, nothing)
  if m.payload.register_future
    d = futures()
    val = get(d, m.uuid, nothing)
    if val !== Discard()
      isnothing(val) || error("Future already has a value: $val")
      insert!(d, m.uuid, m.payload.value)
    else
      delete!(d, m.uuid)
    end
  end
  if !isnothing(command)
    delete!(messages, m.uuid)
    (command::Message{Command}).payload.continuation(m.payload.value)
  end
  !m.payload.register_future && isnothing(command) && @warn("$(current_task()): Received a value for command $(m.uuid) but no matching command has been registered.")
end

"Placeholder for a `Future` UUID to prevent any value from being stored for this `Future`."
struct Discard end

mutable struct Future
  uuid::UUID
  value::Ref{Any}
  from::Task
  function Future(uuid::UUID, task::Task)
    future = new(uuid, Ref{Any}(), task)
    finalizer(future) do x
      isdefined(x.value, 1) && return
      d = futures()
      haskey(d, x.uuid) && return delete!(d, x.uuid)
      insert!(d, x.uuid, Discard())
    end
  end
end

futures() = get!(Dictionary{UUID,Any}, task_local_storage(), :futures)::Dictionary{UUID,Any}

@enum FetchStatus TIMEOUT SHUTDOWN

function Base.fetch(future::Future, timeout::Real = Inf, sleep_time::Real = 0)
  isdefined(future.value, 1) && return future.value[]
  d = futures()
  status = nothing
  wait_timeout(timeout, sleep_time) do
    manage_messages()
    if shutdown_scheduled()
      status = SHUTDOWN
      return true
    end
    istaskfailed(future.from) && wait(future.from)
    haskey(d, future.uuid)
  end || (status = TIMEOUT)
  !isnothing(status) && return status
  ret = d[future.uuid]
  delete!(d, future.uuid)
  future.value[] = ret
end
