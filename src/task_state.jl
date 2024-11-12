tls_key(x) = Symbol(:CooperativeTasks, '_', x)

const TLS_SHUTDOWN_SCHEDULED = tls_key(:mpi_shutdown_scheduled)
const TLS_CHANNEL = tls_key(:mpi_channel)
const TLS_PENDING_MESSAGES = tls_key(:mpi_pending_messages)
const TLS_CONNECTIONS = tls_key(:mpi_connections)
const TLS_TASK_STATES = tls_key(:mpi_task_states)
const TLS_TASK_OWNER = tls_key(:mpi_task_owner)
const TLS_UNPROCESSED_MESSAGES = tls_key(:mpi_unprocessed_messages)
const TLS_CHILDREN_TASKS = tls_key(:mpi_children_tasks)
const TLS_ERROR_HANDLERS = tls_key(:mpi_error_handlers)
const TLS_FUTURES = tls_key(:mpi_futures)

function channel(task::Task)
  tls = Base.get_task_tls(task)
  val = get(tls, TLS_CHANNEL, nothing)
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

shutdown_scheduled() = get!(task_local_storage(), TLS_SHUTDOWN_SCHEDULED, false)::Bool

function schedule_shutdown()
  # @debug "Shutdown was scheduled on $(task_repr())\n$(sprint(showerror, ErrorException(""), backtrace(); context = :color => true))"
  task_local_storage(TLS_SHUTDOWN_SCHEDULED, true)
end

channel() = get!(task_local_storage(), TLS_CHANNEL, Channel{Message}(Inf))::Channel{Message}

pending_messages() = get!(PendingMessages, task_local_storage(), TLS_PENDING_MESSAGES)::PendingMessages

# Prefer using `state(::Task)` rather than iterating values.
task_states() = get!(Dictionary{Task,TaskState}, task_local_storage(), TLS_TASK_STATES)::Dictionary{Task,TaskState}
known_tasks() = keys(task_states())

task_owner() = task_local_storage(TLS_TASK_OWNER)::Union{Task,Nothing}
set_task_owner(value) = task_local_storage(TLS_TASK_OWNER, value)::Union{Task,Nothing}

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

unprocessed_messages() = get!(Vector{Message}, task_local_storage(), TLS_UNPROCESSED_MESSAGES)::Vector{Message}

owned_tasks() = get!(Vector{Task}, task_local_storage(), TLS_CHILDREN_TASKS)::Vector{Task}

error_handlers() = get!(Dictionary{Task,Any}, task_local_storage(), TLS_ERROR_HANDLERS)::Dictionary{Task,Any}

futures() = get!(Dictionary{UUID,Any}, task_local_storage(), TLS_FUTURES)::Dictionary{UUID,Any}

function next_message()
  m = take!(channel())
  set_task_state(m.from, ALIVE)
  m
end

function reset_task_state()
  empty!(pending_messages())
  empty!(task_states())
  empty!(unprocessed_messages())
  empty!(owned_tasks())
  empty!(error_handlers())
  empty!(futures())
  task_local_storage(TLS_TASK_OWNER, nothing)
  task_local_storage(TLS_CHANNEL, Channel{Message}(Inf))
  nothing
end

function reset()
  wait(shutdown_owned_tasks())
  manage_messages()
  reset_task_state()
end
