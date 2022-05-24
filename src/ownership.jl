children_tasks() = get!(Vector{Task}, task_local_storage(), :children_tasks)

function set_task_owner(owner::Task)
  tls = task_local_storage()
  if haskey(tls, :task_owner)
    task = tls[:task_owner]
    isa(task, Task) || error("Key :task_owner already exists in task-local storage, and is not a `Task`.")
    remove_owner(task)
  end
  tls[:task_owner] = owner
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

has_owner() = haskey(task_local_storage(), :task_owner)

"Request a parent task to remove the current task as child."
function remove_owner(owner::Task)
  curr_t = current_task()
  command = Command() do
    children = children_tasks()
    i = findfirst(==(curr_t), children)
    isnothing(i) && error("Task $curr_t is not owned by $owner.")
    deleteat!(children, i)
  end
  delete!(task_local_storage(), :task_owner)
  send(owner, command)
end

function shutdown_children()
  foreach(shutdown, children_tasks())
  empty!(children_tasks())
  nothing
end
