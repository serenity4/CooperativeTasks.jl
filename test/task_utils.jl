"""
Retrieve the task owner by snooping at task-local state.

This function is not concurrent, use with care.
"""
function task_owner(t::Task)
  tls = Base.get_task_tls(t)
  get(tls, :task_owner, nothing)
end
