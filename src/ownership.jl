function set_task_owner(owner::Task)
  tls = task_local_storage()
  if haskey(tls, :task_owner)
    task = tls[:task_owner]
    isa(task, Task) || error("Key :task_owner already exists in task-local storage, and is not a `Task`.")
    send(task, Command(remove_child, current_task()))
  end
  tls[:task_owner] = owner
  set!(error_handlers(), task, throw)
  owner
end

function own(task::Task)
  task in children_tasks() && error("Task $task is already owned.")
  curr_t = current_task()
  push!(children_tasks(), task)
  call(set_task_owner, task, curr_t; critical = true)
end

function owner()
  tls = task_local_storage()
  haskey(tls, :task_owner) || error("No owner found for task $task.")
  tls[:task_owner]::Task
end

has_owner() = isa(task_local_storage(:task_owner), Task)

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
  empty!(children_tasks())
  cond
end

function shutdown(tasks::AbstractVector{Task})
  conds = shutdown.(tasks)
  Condition(() -> all(poll, conds))
end
