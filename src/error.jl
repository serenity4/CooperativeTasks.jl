const Backtrace = Vector{Union{Ptr{Nothing}, Base.InterpreterIP}}

struct ChildFailedException <: Exception
  child::Task
  exc::Exception
  bt::Backtrace
  ChildFailedException(exc::Exception, bt::Backtrace) = new(current_task(), exc, bt)
end

function Base.showerror(io::IO, exc::ChildFailedException)
  exc.exc isa ChildFailedException && return showerror(io, exc.exc)
  print(io, "ChildFailedException: Child task ")
  printstyled(io, exc.child; color = :yellow)
  println(io, " failed:\n")
  showerror(io, exc.exc, exc.bt)
  println(io)
end

function handle_error(exc::ChildFailedException)
  set_task_state(exc.child, DEAD)
  f = error_handler(exc.child)
  f(exc)
end

error_handler(child::Task) = get(error_handlers(), child, throw)

function propagate_error(exc::ChildFailedException)
  has_owner() || return @error "Task failed and found no parent to propagate the error to:" exception = (exc.exc, exc.bt)
  task = owner()
  remove_owner(task)
  send(task, Command(handle_error, exc))
end

function try_execute(f)
  try
    f()
  catch exc
    # Manage messages marked as critical which indicate e.g.
    # a change of ownership or other information that can
    # affect how the error is handled.
    manage_critical_messages()
    propagate_error(ChildFailedException(exc, catch_backtrace()))
    schedule_shutdown()
    exc isa InterruptException
  end
end

function shutdown_on_failure(tasks)
  for task in tasks
    if state(task) == DEAD
      wait(shutdown(tasks))
      return true
    end
  end
  false
end

function monitor_children(period::Real = 0.001; allow_failures = true)
  tasks = children_tasks()
  handlers = error_handlers()

  err_handler = Base.Fix1(showerror, stdout)

  for task in tasks
    set!(handlers, task, err_handler)
  end

  try
    wait_timeout(Inf, period) do
      try
        manage_messages()
        !allow_failures && shutdown_on_failure(tasks) && return true
        shutdown_scheduled() && return true
        all(istaskdone, tasks)
      catch e
        isa(e, InterruptException) || rethrow()
        true
      end
    end
  catch e
    isa(e, InterruptException) || rethrow()
  end
  shutdown_scheduled() && shutdown()
  nothing
end
