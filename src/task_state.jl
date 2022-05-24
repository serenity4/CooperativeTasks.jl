function channel(task::Task)
  tls = Base.get_task_tls(task)
  val = get(tls, :mpi_channel, nothing)
  isnothing(val) && error("A MPI channel must be created on the target task before sending or receiving any messages.")
  val::Channel{Message}
end

const PendingMessages = Dictionary{UUID,Message}

shutdown_scheduled() = haskey(task_local_storage(), :mpi_shutdown_scheduled)

schedule_shutdown() = task_local_storage(:mpi_shutdown_scheduled, nothing)

channel() = get!(() -> Channel{Message}(Inf), task_local_storage(), :mpi_channel)::Channel{Message}

pending_messages() = get!(PendingMessages, task_local_storage(), :mpi_pending_messages)::PendingMessages

unprocessed_messages() = get!(Vector{Message}, task_local_storage(), :mpi_unprocessed_messages)::Vector{Message}

acks() = get!(Dictionary{UUID,Bool}, task_local_storage(), :mpi_acks)

ack_received(uuid::UUID) = get(acks(), uuid, false)

next_message() = take!(channel())

function init(task::Task = current_task())
  tls = Base.get_task_tls(task)
  tls[:mpi_channel] = Channel{Message}(Inf)
end
