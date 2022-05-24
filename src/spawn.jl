macro spawn(ex)
  sync_var = esc(Base.sync_varname)
  quote
    task = Task(() -> $(esc(ex)))
    init(task)
    future = own(task)

    # Allow task to run on any OS thread.
    task.sticky = false

    # Support use with `@sync` blocks.
    $(Expr(:islocal, sync_var)) && put!($sync_var, task)

    schedule(task)
    fetch(future, 5, 0) === current_task() || error("Failed to acquire ownership of $task.")
    task
  end
end
