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

failed(value = nothing) = Result(FAILED, value)
success(value = nothing) = Result(SUCCESS, value)

status(result::Result) = result.status
value(result::Result) = result.value

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

default_continuation(ret::Result, args...) = !is_success(ret) ? @warn("Non-success status $(status(ret)) returned (returned value: $(value(ret)))") : nothing

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
  ret = try
    success(Base.invokelatest(payload.f, payload.args...; payload.kwargs...))
  catch e
    isa(e, ChildFailedException) && rethrow()
    failed((e, catch_backtrace()))
  end
  send(command.from, Message(ReturnedValue(ret), command.uuid; command.critical))
end

function Base.show(io::IO, ::MIME"text/plain", result::Result)
  if status(result) == FAILED && result.value isa Tuple{<:Exception, Backtrace}
    println(io, "Failed result:\n")
    return showerror(io, result.value...)
  end
  show(io, result)
end

struct ReturnedValue
  value::Any
end

function process_message(m::Message{ReturnedValue})
  d = futures()
  val = get(d, m.uuid, nothing)
  if val === Discard()
    delete!(d, m.uuid)
  else
    isnothing(val) || error("Future already returned a value: $val")
    insert!(d, m.uuid, m.payload.value)
  end
  messages = pending_messages()
  command = get(messages, m.uuid, nothing)
  if !isnothing(command)
    delete!(messages, m.uuid)
    ret = m.payload.value
    !isa(ret, Result) && (ret = success(ret))
    Base.invokelatest((command::Message{Command}).payload.continuation, ret)
  end
end

"Placeholder for a `Future` UUID to prevent any value from being stored for this `Future`."
struct Discard end

mutable struct Future
  uuid::UUID
  value::Ref{Any}
  from::Task
  to::Task
  function Future(uuid::UUID, from::Task)
    future = new(uuid, Ref{Any}(), from, current_task())
    finalizer(future) do x
      isdefined(x.value, 1) && return
      d = futures()
      haskey(d, x.uuid) && return delete!(d, x.uuid)
      insert!(d, x.uuid, Discard())
    end
  end
end

mutable struct Condition
  test::Any
  passed::Union{Nothing,Bool}
  Condition(test) = new(test, nothing)
end

function Base.wait(cond::Condition; timeout::Real = Inf, sleep_time::Real = 0)
  if isnothing(cond.passed)
    result = wait_timeout(timeout, sleep_time) do
      manage_messages()
      shutdown_scheduled() && return nothing
      cond.test()
    end
    isnothing(result) && return false
    cond.passed = result
  end
  cond.passed
end

function poll(cond::Condition)
  !isnothing(cond.passed) && return cond.passed
  cond.test() ? (cond.passed = true) : false
end

futures() = get!(Dictionary{UUID,Any}, task_local_storage(), :futures)::Dictionary{UUID,Any}

function Base.fetch(future::Future; timeout::Real = Inf, sleep_time::Real = 0)
  isdefined(future.value, 1) || compute(future, timeout, sleep_time)
  future.value[]
end

function compute(future::Future, timeout, sleep_time)
  current_task() === future.to || error("A future must be waited on from the thread that expects the result.")
  d = futures()
  success = wait(Condition(() -> haskey(d, future.uuid)); timeout, sleep_time)
  if success
    future.value[] = d[future.uuid]
    delete!(d, future.uuid)
  else
    future.value[] = failed()
  end
end
