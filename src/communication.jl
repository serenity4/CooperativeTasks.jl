"""
Status code used for communicating success, failures and possibly other intermediate return modes.
"""
@enum StatusCode::Int64 begin
  SUCCESS = 0
  TIMEOUT = 1
  SHUTDOWN_RECEIVED = 2
  FAILED = -1
  RECEIVER_DEAD = -2
end

struct TaskException <: Exception
  msg::String
  code::StatusCode
end

TaskException(code::StatusCode) = TaskException("", code)

Base.showerror(io::IO, e::TaskException) = print(io, e.code, ": ", e.msg)

"Send a message `m` to `task`, unless the task is dead."
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
