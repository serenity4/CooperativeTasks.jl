function channel(task::Task)
  tls = Base.get_task_tls(task)
  val = get(tls, :mpi_channel, nothing)
  isnothing(val) && error("A MPI channel must be created on the target task before sending or receiving any messages.")
  val::Channel{Message}
end

const PendingMessages = Dictionary{UUID,Message}

"Task state hinting at whether it should or may not answer to future requests."
@enum TaskState::Int8 begin
  ALIVE = 0
  UNRESPONSIVE = 1
  DEAD = 2
end

"Communication is theoretically possible with the task."
ALIVE
"The task has timed out once or more on recent requests and has not shown activity since then."
UNRESPONSIVE
"The task is no longer running; either it has signalled its death or it is marked as done."
DEAD

shutdown_scheduled() = get!(task_local_storage(), :mpi_shutdown_scheduled, false)::Bool

schedule_shutdown() = task_local_storage(:mpi_shutdown_scheduled, true)

channel() = get!(task_local_storage(), :mpi_channel, Channel{Message}(Inf))::Channel{Message}

pending_messages() = get!(PendingMessages, task_local_storage(), :mpi_pending_messages)::PendingMessages

connections() = get!(Dictionary{Task,Connection}, task_local_storage(), :mpi_connections)::Dictionary{Task,Connection}

# Prefer using `state(::Task)` rather than iterating values.
task_states() = get!(Dictionary{Task,TaskState}, task_local_storage(), :mpi_task_states)::Dictionary{Task,TaskState}
known_tasks() = keys(task_states())

function set_task_state(task::Task, state::TaskState)
  set!(task_states(), task, state)
  state
end

function state(task::Task)
  st = get(task_states(), task, nothing)
  if isnothing(st)
    set_task_state(task, istaskdone(task) ? DEAD : ALIVE)
  elseif st == ALIVE && istaskdone(task)
    set_task_state(task, DEAD)
  else
    st
  end
end

unprocessed_messages() = get!(Vector{Message}, task_local_storage(), :mpi_unprocessed_messages)::Vector{Message}

acks() = get!(Dictionary{UUID,Bool}, task_local_storage(), :mpi_acks)::Dictionary{UUID,Bool}

ack_received(uuid::UUID) = get(acks(), uuid, false)

children_tasks() = get!(Vector{Task}, task_local_storage(), :children_tasks)::Vector{Task}

error_handlers() = get!(Dictionary{Task,Any}, task_local_storage(), :error_handlers)::Dictionary{Task,Any}

futures() = get!(Dictionary{UUID,Any}, task_local_storage(), :futures)::Dictionary{UUID,Any}

function next_message()
  m = take!(channel())
  set_task_state(m.from, ALIVE)
  m
end

function reset_task_state()
  empty!(pending_messages())
  empty!(connections())
  empty!(task_states())
  empty!(unprocessed_messages())
  empty!(acks())
  empty!(children_tasks())
  empty!(error_handlers())
  empty!(futures())
  task_local_storage(:mpi_channel, Channel{Message}(Inf))
  nothing
end

function reset_all()
  wait(shutdown_children())
  manage_messages()
  reset_task_state()
end
