using ConcurrencyGraph: TLS_TASK_OWNER

"""
Retrieve the task owner by snooping at task-local state.

This function is not concurrent, use with care.
"""
function task_owner(t::Task)
  tls = Base.get_task_tls(t)
  get(tls, TLS_TASK_OWNER, nothing)
end

function capture_stdout(f)
  ret = captured = nothing
  mktemp() do _, io
    withenv("JULIA_DEBUG" => "") do
      redirect_stdout(io) do
        ret = f()
        [sleep(0.1) for _ in 1:5]
      end
      seekstart(io)
      captured = read(io, String)
    end
  end
  ret, captured
end
