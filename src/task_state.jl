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

shutdown_scheduled() = task_local_storage(:mpi_shutdown_scheduled)::Bool

schedule_shutdown() = task_local_storage(:mpi_shutdown_scheduled, true)

channel() = task_local_storage(:mpi_channel)::Channel{Message}

pending_messages() = task_local_storage(:mpi_pending_messages)::PendingMessages

connections() = task_local_storage(:mpi_connections)::Dictionary{Task,Connection}

task_states() = task_local_storage(:mpi_task_states)::Dictionary{Task,TaskState}

set_task_state(task::Task, state::TaskState) = set!(task_states(), task, state)
state(task::Task) = get(task_states(), task, nothing)

unprocessed_messages() = get!(Vector{Message}, task_local_storage(), :mpi_unprocessed_messages)::Vector{Message}

acks() = task_local_storage(:mpi_acks)::Dictionary{UUID,Bool}

ack_received(uuid::UUID) = get(acks(), uuid, false)

children_tasks() = task_local_storage(:children_tasks)::Vector{Task}

function next_message()
  m = take!(channel())
  set_task_state(m.from, ALIVE)
  m
end

function init()
  task_local_storage(:mpi_channel, Channel{Message}(Inf))
  task_local_storage(:mpi_shutdown_scheduled, false)
  task_local_storage(:mpi_pending_messages, PendingMessages())
  task_local_storage(:mpi_connections, Dictionary{Task,Connection}())
  task_local_storage(:mpi_task_states, Dictionary{Task,TaskState}())
  task_local_storage(:mpi_acks, Dictionary{UUID,Bool}())
  task_local_storage(:task_owner, nothing)
  task_local_storage(:children_tasks, Task[])
end
