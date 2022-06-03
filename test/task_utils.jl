function reinit()
  ConcurrencyGraph.shutdown_children()
  ConcurrencyGraph.init()
end

function istasksuccessful(task::Task)
  !istaskfailed(task) && istaskdone(task) && return true
  if istaskdone(task)
    if task._isexception
      if task.result isa Exception
        @error "Task was not successful:" exception = (task.result::Exception, task.backtrace)
      end
      false
    else
      true
    end
  end
  false
end

"""
Retrieve the task owner by snooping at task-local state.

This function is not concurrent, use with care.
"""
function task_owner(t::Task)
  tls = Base.get_task_tls(t)
  get(tls, :task_owner, nothing)
end
