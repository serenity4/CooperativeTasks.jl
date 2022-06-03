struct Message{T}
  from::Task
  uuid::UUID
  payload::T
  ack::RefValue{Bool}
  critical::Bool
  Message(payload, uuid::UUID = uuid(); critical = false) = new{typeof(payload)}(current_task(), uuid, payload, Ref(false), critical)
end

"Send a message `m` to `task`."
send(task::Task, @nospecialize(m::Message)) = send(channel(task), m)
send(ch::Channel{Message}, @nospecialize(m::Message)) = put!(ch, m)
send(task_or_ch::Union{Task,Channel{Message}}, @nospecialize(m); critical = false) = send(task_or_ch, Message(m; critical))

"""
Shut down a task by cancelling it if it has not completed.

See [`cancel`](@ref).
"""
function shutdown(task::Task)
  !istaskstarted(task) && return true
  istaskdone(task) && return true
  cancel(task)
end

function cancel(task::Task; timeout = 2, sleep_time = 0.01)
  send(task, Command(schedule_shutdown))
end

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
    m.ack[] && send(m.from, Ack(m.uuid))
    push!(to_process, m)
  end

  to_process
end

struct Ack
  uuid::UUID
end

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
