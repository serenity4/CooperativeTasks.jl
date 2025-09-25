const Backtrace = Vector{Union{Ptr{Nothing}, Base.InterpreterIP}}

struct ExecutionError <: Exception
  task::Task # task on which the error originates
  exc::Exception
  bt::Backtrace
  ExecutionError(exc::Exception, bt::Backtrace) = new(current_task(), exc, bt)
end

function Base.showerror(io::IO, exc::ExecutionError)
  exc.exc isa ExecutionError && return showerror(io, exc.exc)
  !isa(exc.exc, PropagatedTaskException) && (io = IOContext(io, :register_line_infos => true))
  print(io, "ExecutionError: Child task ")
  printstyled(io, exc.task; color = :yellow)
  println(io, " failed:\n")
  showerror(io, exc.exc, exc.bt)
  println(io)
end

struct PropagatedTaskException <: Exception
  from::Union{Task,Vector{Task}}
  exc::Exception
  function PropagatedTaskException(exc::Exception)
    if isa(exc, PropagatedTaskException)
      from = @set exc.from = [exc.from; current_task()]
      return new(from, exc.exc)
    end
    return new(current_task(), exc)
  end
end

task_that_threw_exception(exc::PropagatedTaskException) = isa(exc.from, Task) ? exc.from : first(exc.from)

function Base.showerror(io::IO, exc::PropagatedTaskException)
  tasks = isa(exc.from, Task) ? [exc.from] : exc.from
  print(io, "Propagated exception from $(join(tasks, " -> ")):\n")
  showerror(io, exc.exc)
end

function handle_error(exc::PropagatedTaskException)
  from = task_that_threw_exception(exc)
  set_task_state(from, DEAD)
  f = error_handler(from)
  f(exc)
end

error_handler(child::Task) = error_handlers()[child]

function propagate_error(exc::Exception)
  if !has_owner()
    # There's no way to rethrow an exception to the main thread, so just log to stderr and hope that someone sees the message.
    return @error "Task failed and found no parent to propagate the error to:" exception = exc
  end
  payload = PropagatedTaskException(exc)
  message = Message(payload; critical = true)
  trysend(task_owner(), message)
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
