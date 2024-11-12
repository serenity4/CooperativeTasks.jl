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

function try_execute(f)
  try
    f()
  catch exc
    # Manage messages marked as critical which indicate e.g.
    # a change of ownership or other information that can
    # affect how the error is handled.
    manage_critical_messages()
    propagate_error(ExecutionError(exc, catch_backtrace()))
    schedule_shutdown()
  end
end

function monitor_children(period::Real = 0.001; allow_failures = false)
  tasks = copy(children_tasks())
  isempty(tasks) && error("No children tasks to monitor")
  handlers = error_handlers()
  err_handler = Base.Fix1(showerror, stdout)
  for task in tasks
    set!(handlers, task, err_handler)
  end

  interrupted = false
  try
    wait_timeout(Inf, period) do
      try
        manage_messages()
        !allow_failures && any(state(task) == DEAD for task in tasks) && return true
        shutdown_scheduled() && return true
        all(istaskdone, tasks)
      catch e
        if isa(e, InterruptException)
          interrupted = true
        else
          wait(shutdown(tasks))
          rethrow()
        end
      end
    end
  catch e
    if isa(e, InterruptException)
      interrupted = true
    else
      wait(shutdown(tasks))
      rethrow()
    end
  end
  # Make sure no children outlives the monitoring parent unless explicitly interrupted (which indicates monitoring might be resumed later).
  !interrupted && !all(istaskdone, tasks) && wait(shutdown(tasks))
  all(istaskdone, tasks)
end

function istasksuccessful(task::Task)
  !istaskfailed(task) && istaskdone(task) && return true
  if istaskdone(task)
    if task._isexception
      if task.result isa Exception
        @error "Task was not successful:" exception = (task.result::Exception, task.backtrace)
      end
      false
    else
      true
    end
  end
  false
end
