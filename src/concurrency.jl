struct Message{T}
  from::Task
  uuid::UUID
  payload::T
  Message(payload, uuid::UUID = uuid()) = new{typeof(payload)}(current_task(), uuid, payload)
end

channel() = get!(() -> Channel{Message}(Inf), task_local_storage(), :mpi_channel)::Channel{Message}
function channel(task::Task)
  tls = Base.get_task_tls(task)
  val = get(tls, :mpi_channel, nothing)
  isnothing(val) && error("A MPI channel must be created on the target task before sending or receiving any messages.")
  val::Channel{Message}
end

const PendingMessages = Dictionary{UUID,Message}
pending_messages() = get!(PendingMessages, task_local_storage(), :mpi_pending_messages)::PendingMessages

function init(task::Task = current_task())
  tls = Base.get_task_tls(task)
  tls[:mpi_pending_messages] = PendingMessages()
  tls[:mpi_channel] = Channel{Message}(Inf)
end

"""
List of tasks which are shutdown via a finalizer once the lifetime of `TaskGroup` expires.
"""
mutable struct TaskGroup
  tasks::Vector{Task}
  function TaskGroup(tasks = Task[])
    tasks = convert(Vector{Task}, tasks)
    finalizer(new(tasks)) do tg
      for task in tg.tasks
        @async shutdown(task)
      end
    end
  end
end

"Send a message `m` to `task`."
send(task::Task, @nospecialize(m::Message)) = send(channel(task), m)
send(ch::Channel{Message}, @nospecialize(m::Message)) = put!(ch, m)
next_message(ch::Channel{Message} = channel()) = take!(ch)

"""
Shut down a task by cancelling it if it has not completed.

See [`cancel`](@ref).
"""
function shutdown(task::Task)
  !istaskstarted(task) && return true
  istaskdone(task) && return true
  cancel(task)
end

struct Cancel end

function cancel(task::Task; timeout = 2, sleep_time = 0.01)
  send(task, Message(Cancel()))
  wait_timeout(task, timeout, sleep_time)
end

function wait_timeout(task::Task, timeout::Real, sleep_time::Real)
  t0 = time()
  while time() - t0 < timeout
    istaskdone(task) && return true
    sleep(sleep_time)
  end
  istaskdone(task)
end

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

Command(f, args...; continuation = nothing, kwargs...) = Command(f, args, kwargs, continuation)

function send(task::Task, command::Message{Command})
  !isnothing(command.payload.continuation) && insert!(pending_messages(), command.uuid, command)
  Base.@invoke send(task::Task, command::Message)
end

children_tasks() = get!(Vector{Task}, task_local_storage(), :children_tasks)

function own(task::Task)
  curr_t = current_task()
  command = Command() do
    tls = task_local_storage()
    if haskey(tls, :task_owner)
      task = tls[:task_owner]
      isa(task, Task) || error("Key :task_owner already exists in task-local storage, and is not a `Task`.")
      remove_owner(task)
    end
    tls[:task_owner] = curr_t
  end
  send(task, Message(command))
  push!(children_tasks(), task)
end

function owner(task::Task = current_task())
  tls = Base.get_task_tls(task)
  haskey(tls, :task_owner) || error("No owner found for task $task.")
  tls[:task_owner]::Task
end

function remove_owner(task::Task)
  curr_t = current_task()
  command = Command() do
    children = children_tasks()
    i = findfirst(==(curr_t), children)
    isnothing(i) && error("Task $curr_t is not owned by $task.")
    deleteat!(children, i)
  end
  send(task, Message(command))
end

function manage_messages(ch::Channel{Message} = channel())
  to_process = Message[]
  while isready(ch)
    m = next_message(ch)
    take_note(m)
    push!(to_process, m)
  end
  shutdown_scheduled() && return
  for m in to_process
    process_message(m)
  end
end

take_note(@nospecialize(::Message)) = nothing
take_note(::Message{Cancel}) = schedule_shutdown()

schedule_shutdown() = task_local_storage(:mpi_shutdown_scheduled, nothing)

function shutdown_scheduled()
  tls = task_local_storage()
  haskey(tls, :mpi_shutdown_scheduled)
end

struct ReturnedValue
  value::Any
end

process_message(@nospecialize(message::Message)) = @warn("Ignoring message of unidentified type $(typeof(message)).")
process_message(::Message{Cancel}) = nothing

function process_message(command::Message{Command})
  (; payload) = command
  ret = Base.invokelatest(payload.f, payload.args...; payload.kwargs...)
  if !isnothing(payload.continuation)
    send(command.from, Message(ReturnedValue(ret), command.uuid)) 
  end
end

function process_message(m::Message{ReturnedValue})
  messages = pending_messages()
  command = get(messages, m.uuid, nothing)
  if !isnothing(command)
    delete!(messages, m.uuid)
    (command::Message{Command}).payload.continuation(m.payload.value)
  else
    @warn("$(current_task()): Received a value for command $(m.uuid) but no matching command has been registered.")
  end
end

abstract type ExecutionMode end

struct Activity
  time::Float64
  duration::Float64
end

mutable struct ExecutionState
  recent_activity::Vector{Activity}
end
ExecutionState() = ExecutionState([])

function record_activity(f, state::ExecutionState)
  t = time()
  timed = @timed try
    f()
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

const Backtrace = Vector{Union{Ptr{Nothing}, Base.InterpreterIP}}

function (exec::LoopExecution)(f = Returns(nothing))
  function _exec()
    interrupted = false
    cancelled = false
    ch = channel()

    # TODO: Remove code duplication for these try/catch blocks.
    try
      manage_messages(ch)
    catch exc
      exc isa InterruptException && (interrupted = true)
      propagate_error(ChildFailedException(exc, Base.catch_backtrace()))
      cancelled = true
    end

    while !cancelled
      t0 = time()
      ret = try
        f()
      catch exc
        exc, Base.catch_backtrace()
      end

      ret === Cancel() && break
      if ret isa Tuple && length(ret) == 2 && first(ret) isa Exception && last(ret) isa Backtrace
        (exc, bt) = ret
        exc isa InterruptException && (interrupted = true)
        propagate_error(ChildFailedException(exc, bt))
        break
      end

      Δt = time() - t0
      # TODO: Record acitivity when collecting messages.
      # Maybe this should be handled by the task itself.
      try
        manage_messages(ch)
      catch exc
        exc isa InterruptException && (interrupted = true)
        propagate_error(ChildFailedException(exc, Base.catch_backtrace()))
        break
      end

      shutdown_scheduled() && (cancelled = true; break)
      while Δt < exec.period || isnothing(exec.period)
        try
          manage_messages(ch)
        catch exc
          exc isa InterruptException && (interrupted = true)
          propagate_error(ChildFailedException(exc, Base.catch_backtrace()))
          break
        end

        shutdown_scheduled() && (cancelled = true; break)
        Δt = time() - t0
        if Δt - exec.period ≥ 0.001 && !has_activity(exec)
          sleep(Δt - exec.period)
        end
        Δt = time() - t0
      end
    end

    shutdown_children()
    interrupted && return interrupt_owner()
  end
end

function shutdown_children()
  for task in children_tasks()
    shutdown(task)
  end
end

function has_activity(exec::ExecutionMode)
  isempty(exec.state.recent_activity) && return false
  time() - last(exec.state.recent_activity).time < 3exec.period
end

struct ChildFailedException <: Exception
  child::Task
  exc::Exception
  bt::Backtrace
  ChildFailedException(exc::Exception, bt::Backtrace) = new(current_task(), exc, bt)
end

function Base.showerror(io::IO, exc::ChildFailedException)
  exc.exc isa ChildFailedException && return showerror(io, exc.exc)
  println(io, "ChildFailedException: Child task $(exc.child) failed:\n")
  showerror(io, exc.exc, exc.bt)
end

propagate_error(exc::ChildFailedException) = send(owner(), Message(Command(throw, exc)))
function interrupt_owner()
  t = owner()
  @async cancel(t)
end

macro spawn(ex)
  sync_var = esc(Base.sync_varname)
  quote
    task = Task(() -> $(esc(ex)))
    init(task)
    own(task)
    task.sticky = false
    $(Expr(:islocal, sync_var)) && put!($sync_var, task)
    schedule(task)
    # TODO: Synchronize with ownership command via an acknowledgment (ack) mechanism.
    sleep(0.2)
    task
  end
end
