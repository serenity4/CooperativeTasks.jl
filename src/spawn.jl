macro spawn(ex)
  sync_var = esc(Base.sync_varname)
  quote
    task = Task(() -> $(esc(ex)))
    init(task)
    uuid = own(task)

    # Allow task to run on any OS thread.
    task.sticky = false

    # Support use with `@sync` blocks.
    $(Expr(:islocal, sync_var)) && put!($sync_var, task)

    schedule(task)
    wait_timeout(5, 0) do
      manage_critical_messages()
      shutdown_scheduled() && return false
      istaskfailed(task) && wait(task)
      !haskey(pending_messages(), uuid)
    end || error("Failed to set owner for $task.")
    task
  end
end
