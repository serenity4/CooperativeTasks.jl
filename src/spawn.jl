macro spawn(mode, ex)
  sync_var = esc(Base.sync_varname)
  quote
    exec = execution_mode($(esc(mode)))
    task = Task(exec(() -> $(esc(ex))))

    # Note: this is not concurrent, be careful to not schedule the task for execution before we are done with `tls`.
    tls = Base.get_task_tls(task)
    tls[:task_owner] = current_task()
    tls[:mpi_channel] = Channel{Message}(Inf)
    tls[:mpi_task_states] = dictionary([current_task() => ALIVE])
    set_task_state(task, ALIVE)

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
