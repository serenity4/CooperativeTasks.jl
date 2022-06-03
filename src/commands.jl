@enum StatusCode::Int64 begin
  SUCCESS = 0
  FAILED = 1
end

Base.convert(::Type{StatusCode}, success::Bool) = StatusCode(!success)

struct Result
  status::StatusCode
  value::Any
end

Result(status) = Result(status, nothing)

failed() = Result(FAILED)
success(value = nothing) = Result(SUCCESS, value)

is_success(result::Result) = result.status == SUCCESS

"""
Execute `ret = f()` on a task, optionally executing `continuation(ret)` from the task the message has been sent from.

First, the command is registered on a source task with a corresponding UUID. Then, as part of a message, it is sent to the destination task for execution, which will send back the value associated with this UUID if any continuation has been provided. If so, when the source task next collects new messages, it will run `continuation` with the returned value.
"""
struct Command
  f::Any
  args::Any
  kwargs::Any
  continuation::Any
end

default_continuation(ret::Result, args...) = is_success(ret) ? nothing : throw_error(ret)

function throw_error(ret::Result)
  if ret.status == FAILED
    if ret.value isa Exception
      throw(ret.value)
    else
      error("FAILED: a failure occurred", isnothing(ret.value) ? "" : "(payload: $(ret.value))")
    end
  else
    error(ret.status, ": non-success status code returned", isnothing(ret.value) ? "" : "(payload: $(ret.value))")
  end
end

Command(f, args...; continuation = default_continuation, kwargs...) = Command(f, args, kwargs, continuation)

function send(task::Task, command::Message{Command})
  !isnothing(command.payload.continuation) && insert!(pending_messages(), command.uuid, command)
  Base.@invoke send(task::Task, command::Message)
  Future(command.uuid, task)
end

function call(f, task::Task, args...; critical = false, kwargs...)
  send(task, Command(f, args...; kwargs...); critical)
end

function execute(f, task::Task, args...; critical = false, kwargs...)
  send(task, Command(f, args...; kwargs...); critical)
end

function process_message(command::Message{Command})
  (; payload) = command
  ret = Base.invokelatest(payload.f, payload.args...; payload.kwargs...)
  send(command.from, Message(ReturnedValue(ret), command.uuid; command.critical))
end

struct ReturnedValue
  value::Any
end

function process_message(m::Message{ReturnedValue})
  messages = pending_messages()
  command = get(messages, m.uuid, nothing)
  d = futures()
  val = get(d, m.uuid, nothing)
  if val !== Discard()
    isnothing(val) || error("Future already has a value: $val")
    insert!(d, m.uuid, m.payload.value)
  else
    delete!(d, m.uuid)
  end
  if !isnothing(command)
    delete!(messages, m.uuid)
    (command::Message{Command}).payload.continuation(m.payload.value)
  end
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

function Base.fetch(future::Future, timeout::Real = Inf, sleep_time::Real = 0)
  isdefined(future.value, 1) || compute(future, timeout, sleep_time)
  val = future.value[]
  val isa Result ? val : success(val)
end

function compute(future::Future, timeout, sleep_time)
  d = futures()
  success = wait_timeout(timeout, sleep_time) do
    manage_messages()
    shutdown_scheduled() && return false
    istaskfailed(future.from) && wait(future.from)
    haskey(d, future.uuid)
  end
  if success
    ret = d[future.uuid]
    delete!(d, future.uuid)
    future.value[] = ret
  else
    future.value[] = failed()
  end
end
