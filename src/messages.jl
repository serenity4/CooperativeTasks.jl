"""
Message sent by a task with an optional payload, identified by a UUID.

If `critical` is set to true, it will be processed before all non-critical messages.
"""
struct Message{T}
  from::Task
  uuid::UUID
  payload::T
  critical::Bool
  Message(payload, uuid::UUID = uuid(); critical = false) = new{typeof(payload)}(current_task(), uuid, payload, critical)
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
  isempty(unprocessed) && return
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
