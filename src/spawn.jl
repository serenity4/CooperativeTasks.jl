macro spawn(mode, ex)
  sync_var = esc(Base.sync_varname)
  quote
    exec = execution_mode($(esc(mode)))
    task = Task(exec(() -> $(esc(ex))))

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
    tls[:error_handlers] = Dictionary{Task,Any}()
    tls[:children_tasks] = Task[]

    # List spawned task as child of the current task.
    push!(children_tasks(), task)


    # Allow task to run on any OS thread.
    task.sticky = false

    # Support use with `@sync` blocks.
    $(Expr(:islocal, sync_var)) && put!($sync_var, task)

    schedule(task)
    task
  end
end

macro spawn(ex) :(@spawn :single $(esc(ex))) end

execution_mode(mode::Symbol) = mode == :single ? SingleExecution() : mode == :looped ? LoopExecution(nothing) : error("Unknown execution mode '$mode'")
execution_mode(mode::ExecutionMode) = mode
