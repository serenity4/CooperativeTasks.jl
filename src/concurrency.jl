struct Message{T}
  from::Task
  uuid::UUID
  payload::T
  ack::RefValue{Bool}
  critical::Bool
  Message(payload, uuid::UUID = uuid(); critical = false) = new{typeof(payload)}(current_task(), uuid, payload, Ref(false), critical)
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

unprocessed_messages() = get!(Vector{Message}, task_local_storage(), :mpi_unprocessed_messages)::Vector{Message}

function init(task::Task = current_task())
  tls = Base.get_task_tls(task)
  tls[:mpi_channel] = Channel{Message}(Inf)
end

"Send a message `m` to `task`."
send(task::Task, @nospecialize(m::Message)) = send(channel(task), m)
send(ch::Channel{Message}, @nospecialize(m::Message)) = put!(ch, m)
next_message() = take!(channel())

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
  wait_timeout(() -> istaskdone(task), timeout, sleep_time)
end

function wait_timeout(test, timeout::Real, sleep_time::Real)
  !iszero(sleep_time) && sleep_time < 0.001 && @warn "Sleep time is less than the granularity of `sleep` ($sleep_time < 0.001)"
  t0 = time()
  while time() - t0 < timeout
    test() && return true
    iszero(sleep_time) ? yield() : sleep(sleep_time)
  end
  test()
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

function manage_messages()
  read_messages()
  shutdown_scheduled() && return
  process_messages()
end

function process_messages()
  messages = unprocessed_messages()
  while !isempty(messages)
    process_message(pop!(messages))
  end
end

function manage_critical_messages()
  read_messages()
  unprocessed = unprocessed_messages()
  mask = findall(m -> m.critical, unprocessed)
  processed = Int[]
  try
    for i in mask
      process_message(unprocessed[i])
      push!(processed, i)
    end
  finally
    deleteat!(unprocessed, processed)
  end
end

function read_messages()
  ch = channel()
  to_process = unprocessed_messages()

  while isready(ch)
    @debug "Current task: "
    @debug "$(Base.text_colors[:yellow])$(current_task())\n$(Base.text_colors[:default])"
    m = next_message()
    @debug "Message received: $m\n"
    take_note(m)
    m.ack[] && send(m.from, Message(Ack(m.uuid)))
    push!(to_process, m)
  end

  to_process
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
    send(command.from, Message(ReturnedValue(ret), command.uuid; command.critical))
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

struct Ack
  uuid::UUID
end

acks() = get!(Dictionary{UUID,Bool}, task_local_storage(), :mpi_acks)

function process_message(m::Message{Ack})
  d = acks()
  (; uuid) = m.payload
  if !haskey(d, uuid)
    @warn "Received unexpected ack for message $(uuid)"
  else
    prev_ack = d[uuid]
    !prev_ack || return @warn "Duplicate ack received for message $(uuid)"
    d[uuid] = true
  end
end

ack_received(uuid::UUID) = get(acks(), uuid, false)

function wait_ack(uuid::UUID; timeout::Real = 5, sleep_time::Real = 0.001)
  success = wait_timeout(timeout, sleep_time) do
    manage_messages()
    ack_received(uuid)
  end
  !success && @warn "Timed out while waiting for ack after $timeout seconds"
  success
end

function send_ack(task_or_ch::Union{Task,Channel}, m::Message; wait_ack = true, timeout::Real = 5, sleep_time::Real = 0.001)
  m.ack[] = true
  insert!(acks(), m.uuid, false)
  send(task_or_ch, m)
  _wait(; timeout::Real = timeout, sleep_time::Real = sleep_time) = @__MODULE__().wait_ack(m.uuid; timeout, sleep_time)
  wait_ack && return _wait()
  _wait
end
