function set_task_owner(owner::Task)
  owner = task_owner()
  !isnothing(owner) && trysend(owner, Command(remove_child, current_task()))
  task_local_storage(TLS_TASK_OWNER, owner)
  set!(error_handlers(), task, throw)
  owner
end

function own(task::Task)
  task in children_tasks() && error("Task $task is already owned.")
  curr_t = current_task()
  push!(children_tasks(), task)
  tryexecute(set_task_owner, task, curr_t; critical = true)
end

has_owner() = !isnothing(task_owner())

"Request a parent task to remove the current task as child."
function remove_child(task::Task)
  children = children_tasks()
  i = findfirst(==(task), children)
  isnothing(i) && return
  deleteat!(children, i)
end

"""
Shutdown all children of the current task.
Returns a [`Condition`](@ref) which can be waited on.
"""
function shutdown_children()
  tasks = children_tasks()
  cond = shutdown(tasks)
  empty!(tasks)
  cond
end

function shutdown(tasks::AbstractVector{Task})
  conds = shutdown.(tasks)
  Condition(() -> all(poll, conds))
end
