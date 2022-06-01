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
end

function propagate_error(exc::ChildFailedException)
  has_owner() || return @error "Task failed and found no parent to propagate the error to:" exception = (exc.exc, exc.bt)
  task = owner()
  remove_owner(task)
  send(task, Command(throw, exc))
end

function try_execute(f)
  try
    f()
  catch exc
    # Manage messages marked as critical which indicate e.g.
    # a change of ownership or other information that can
    # affect how the error is handled.
    manage_critical_messages()
    signal_failure()
    propagate_error(ChildFailedException(exc, catch_backtrace()))
    schedule_shutdown()
    exc isa InterruptException
  end
end

function signal_failure()
  
end
