macro spawn(mode, ex)
  sync_var = esc(Base.sync_varname)
  isa(mode, QuoteNode) && (mode = mode.value)
  exec = execution_mode(mode)
  quote
    task = Task($exec(() -> $(esc(ex))))

    # Setup required task-local storage.
    # Note: this is not concurrent, be careful to not schedule the task for execution before we are done with `tls`.
    # Always keep in sync with the `init` function which sets this up locally.
    tls = Base.get_task_tls(task)
    tls[:task_owner] = current_task()
    tls[:mpi_channel] = Channel{Message}(Inf)
    tls[:mpi_shutdown_scheduled] = false
    tls[:mpi_pending_messages] = PendingMessages()
    tls[:mpi_connections] = Dictionary{Task,Connection}()
    tls[:mpi_task_states] = Dictionary{Task,TaskState}()
    tls[:mpi_acks] = Dictionary{UUID,Bool}()
    tls[:children_tasks] = Task[]
    push!(children_tasks(), task)


    # Allow task to run on any OS thread.
    task.sticky = false

    # Support use with `@sync` blocks.
    $(Expr(:islocal, sync_var)) && put!($sync_var, task)

    schedule(task)
    errormonitor(task)
    task
  end
end

macro spawn(ex) :(@spawn :single $(esc(ex))) end

execution_mode(mode::Symbol) = mode == :single ? SingleExecution() : mode == :looped ? LoopExecution(nothing) : error("Unknown execution mode '$mode'")
execution_mode(mode::ExecutionMode) = mode
