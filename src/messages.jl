struct Message{T}
  from::Task
  uuid::UUID
  payload::T
  ack::RefValue{Bool}
  critical::Bool
  Message(payload, uuid::UUID = uuid(); critical = false) = new{typeof(payload)}(current_task(), uuid, payload, Ref(false), critical)
end

"Send a message `m` to `task`."
function trysend(task::Task, @nospecialize(m::Message))::Result{Message,TaskException}
  state(task) == DEAD && return TaskException(RECEIVER_DEAD)
  trysend(channel(task), m)
end
trysend(ch::Channel{Message}, @nospecialize(m::Message)) = put!(ch, m)
trysend(task_or_ch::Union{Task,Channel{Message}}, @nospecialize(m); critical = false) = trysend(task_or_ch, Message(m; critical))

"""
Shut down a task by cancelling it if it has not completed.

See [`cancel`](@ref).
"""
function shutdown(task::Task)
  !istaskstarted(task) && return Condition(Returns(true))
  istaskdone(task) && return Condition(Returns(true))
  @debug "Cancelling task $(task_repr(task)) from $(task_repr())"
  cancel(task)
  Condition(() -> state(task) == DEAD)
end

cancel(task::Task) = trysend(task, Command(schedule_shutdown); critical = true)

function wait_timeout(test, timeout::Real, sleep_time::Real)
  !iszero(sleep_time) && sleep_time < 0.001 && @warn "Sleep time is less than the granularity of `sleep` ($sleep_time < 0.001)"
  t0 = time()
  while time() - t0 < timeout
    test() === true && return true
    iszero(sleep_time) ? yield() : sleep(sleep_time)
  end
  test() === true
end

process_message(@nospecialize(message::Message)) = @warn("Ignoring message of unidentified type $(typeof(message)).")

function manage_messages()
  manage_critical_messages()
  shutdown_scheduled() && return
  process_messages()
end

function process_messages()
  messages = unprocessed_messages()
  while !isempty(messages)
    m = pop!(messages)
    state(m.from) == UNRESPONSIVE && set_task_state(m.from, ALIVE)
    process_message(m)
    shutdown_scheduled() && break
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

task_repr(task = current_task()) = string(Base.text_colors[:yellow], task, Base.text_colors[:default])

function read_messages()
  ch = channel()
  to_process = unprocessed_messages()

  while isready(ch)
    m = next_message()::Message
    @debug "Message (of type $(nameof(typeof(m.payload)))) received on $(task_repr()) from $(task_repr(m.from))" * ( m.critical ? " (critical)" : "")
    push!(to_process, m)
  end

  to_process
end
