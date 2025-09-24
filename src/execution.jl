struct Activity
  time::Float64
  duration::Float64
end

mutable struct ExecutionState
  recent_activity::Vector{Activity}
end
ExecutionState() = ExecutionState([])

function record_activity(f, state::ExecutionState)
  t = time()
  timed = @timed try
    f()
  catch e
    e
  end
  length(state.recent_activity) ≥ 100 && popfirst!(state.recent_activity)
  push!(state.recent_activity, Activity(t, timed.time))
  timed.value
end

function has_activity(state::ExecutionState)
  isempty(state.recent_activity) && return false
  time() - last(state.recent_activity).time < 3exec.period
end

"Execute a function once, then return."
Base.@kwdef struct SingleExecution
  """
  Whether to call `shutdown()` on this task after the loop finishes executing.

  Can be useful in contexts where [`SingleExecution`](@ref) and [`LoopExecution`](@ref) are mixed together, to avoid shutting down multiple times.
  """
  shutdown::Bool = true
end

function (exec::SingleExecution)(f = Returns(nothing))
  function _exec()
    try_execute(f)
    shutdown()
  end
end

"""
Execute a function repeatedly until a shutdown is scheduled with [`schedule_shutdown`](@ref).

If `period` is greater than a millisecond, every iteration may trigger a sleep
for the remaining period time after executing the main function.
Simple heuristics are used to prevent sleeping when there were recent interactions
with other tasks, to avoid suffering from large communication delays.

At every iteration, task messages will be checked and allow (among other things)
to compute/return results to other tasks (see [`Future`](@ref)), and to cancel the task.
This mode of execution is preferred over manual loops precisely for the ability to satisfy
task duties as required in the context of this library.
"""
struct LoopExecution
  period::Union{Nothing,Float64}
  state::ExecutionState
  """
  Whether to call `shutdown()` on this task after the loop finishes executing.

  Can be useful in contexts where [`SingleExecution`](@ref) and [`LoopExecution`](@ref) are mixed together, to avoid shutting down multiple times.
  """
  shutdown::Bool
end
LoopExecution(period; shutdown = true) = LoopExecution(period, ExecutionState(), shutdown)

function (exec::LoopExecution)(f = Returns(nothing))
  function _exec()
    # TODO: Record activity when collecting messages.
    try_execute(manage_messages)

    while !shutdown_scheduled()
      t0 = time()

      try_execute(f)
      shutdown_scheduled() && @goto out
      try_execute(manage_messages)
      shutdown_scheduled() && @goto out

      if isnothing(exec.period)
        yield()
        continue
      end

      Δt = time() - t0

      while Δt < exec.period

        try_execute(manage_messages)
        shutdown_scheduled() && @goto out

        Δt = time() - t0
        if Δt - exec.period ≥ 0.001 && !has_activity(exec.state)
          sleep(Δt - exec.period)
        else
          yield()
        end
        Δt = time() - t0
      end
    end

    @label out
    exec.shutdown && shutdown()
  end
end

function try_execute(f)
  try
    f()
  catch exc
    # Manage messages marked as critical which indicate e.g.
    # a change of ownership or other information that can
    # affect how the error is handled.
    manage_critical_messages()
    propagate_error(ExecutionError(exc, catch_backtrace()))
    schedule_shutdown()
  end
end

function shutdown()
  !shutdown_scheduled() && schedule_shutdown() # in case it was not already set as scheduled
  @debug "Shutting down on $(task_repr())"
  cond = shutdown_owned_tasks()
  for t in known_tasks()
    state(t) ≠ DEAD && signal_shutdown(t)
  end
  cond
end

signal_shutdown(task::Task) = tryexecute(set_task_state, task, current_task(), DEAD)
