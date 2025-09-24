function set_task_owner(owner::Task)
  owner = task_owner()
  !isnothing(owner) && trysend(owner, Command(remove_child, current_task()))
  task_local_storage(TLS_TASK_OWNER, owner)
  set!(error_handlers(), task, throw)
  owner
end

function own(task::Task)
  task in owned_tasks() && error("Task $task is already owned.")
  curr_t = current_task()
  push!(owned_tasks(), task)
  tryexecute(set_task_owner, task, curr_t; critical = true)
end

has_owner() = !isnothing(task_owner())

"Request a parent task to remove the current task as child."
function remove_child(task::Task)
  children = owned_tasks()
  i = findfirst(==(task), children)
  isnothing(i) && return
  deleteat!(children, i)
end

"""
Shutdown all children of the current task.
Returns a `Condition` which can be waited on.
"""
function shutdown_owned_tasks()
  tasks = owned_tasks()
  cond = shutdown(tasks)
  empty!(tasks)
  cond
end

function shutdown(tasks::AbstractVector{Task})
  conds = shutdown.(tasks)
  Condition(() -> all(poll, conds))
end

function monitor_owned_tasks(period::Real = 0.001; allow_failures = false)
  tasks = copy(owned_tasks())
  isempty(tasks) && error("No children tasks to monitor")
  handlers = error_handlers()
  err_handler = function (exc::Exception)
    io = IOContext(stdout, :register_line_infos => false)
    showerror(io, exc)
  end
  for task in tasks
    set!(handlers, task, err_handler)
  end

  interrupted = false
  try
    wait_timeout(Inf, period) do
      try
        manage_messages()
        !allow_failures && any(state(task) == DEAD for task in tasks) && return true
        shutdown_scheduled() && return true
        all(istaskdone, tasks)
      catch e
        if isa(e, InterruptException)
          interrupted = true
        else
          wait(shutdown(tasks))
          rethrow()
        end
      end
    end
  catch e
    if isa(e, InterruptException)
      interrupted = true
    else
      wait(shutdown(tasks))
      rethrow()
    end
  end
  # Make sure no children outlives the monitoring parent unless explicitly interrupted (which indicates monitoring might be resumed later).
  !interrupted && !all(istaskdone, tasks) && wait(shutdown(tasks))
  all(istaskdone, tasks)
end
