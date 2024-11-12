const Backtrace = Vector{Union{Ptr{Nothing}, Base.InterpreterIP}}

struct ExecutionError <: Exception
  task::Task
  exc::Exception
  bt::Backtrace
  ExecutionError(exc::Exception, bt::Backtrace) = new(current_task(), exc, bt)
end

function Base.showerror(io::IO, exc::ExecutionError)
  exc.exc isa ExecutionError && return showerror(io, exc.exc)
  print(io, "ExecutionError: Child task ")
  printstyled(io, exc.task; color = :yellow)
  println(io, " failed:\n")
  showerror(io, exc.exc, exc.bt)
  println(io)
end

struct PropagatedTaskException <: Exception
  exc::ExecutionError
end

function Base.showerror(io::IO, exc::PropagatedTaskException)
  print(io, "Propagated ")
  showerror(io, exc.exc)
end

function handle_error(exc::PropagatedTaskException)
  set_task_state(exc.exc.task, DEAD)
  f = error_handler(exc.exc.task)
  f(exc)
end

error_handler(child::Task) = error_handlers()[child]

function propagate_error(exc::ExecutionError)
  has_owner() && return trysend(task_owner(), Command(handle_error, PropagatedTaskException(exc)))
  # There's no way to rethrow an exception to the main thread, so just log to stderr and hope that someone sees the message.
  @error "Task failed and found no parent to propagate the error to:" exception = (exc.exc, exc.bt)
end

"""
Check whether the task has successfully terminated execution.

By default, an error will be logged if an exception was found; set `log = false` to prevent that.
"""
function istasksuccessful(task::Task; log::Bool = true)
  !istaskfailed(task) && istaskdone(task) && return true
  if istaskdone(task)
    if task._isexception
      if log && task.result isa Exception
        @error "Task was not successful:" exception = (task.result::Exception, task.backtrace)
      end
      false
    else
      true
    end
  end
  false
end
