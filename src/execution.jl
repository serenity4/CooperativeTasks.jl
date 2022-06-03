abstract type ExecutionMode end

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

struct SingleExecution <: ExecutionMode end

function (exec::SingleExecution)(f = Returns(nothing))
  function _exec()
    try_execute(f)
    shutdown_children()
  end
end

struct LoopExecution <: ExecutionMode
  period::Union{Nothing,Float64}
  state::ExecutionState
end
LoopExecution(period) = LoopExecution(period, ExecutionState())

function (exec::LoopExecution)(f = Returns(nothing))
  function _exec()
    # TODO: Record activity when collecting messages.
    try_execute(manage_messages)

    while !shutdown_scheduled()
      t0 = time()

      try_execute(f)
      shutdown_scheduled() && break

      try_execute(manage_messages)
      isnothing(exec.period) && continue

      Δt = time() - t0

      while Δt < exec.period

        try_execute(manage_messages)
        shutdown_scheduled() && @goto out

        Δt = time() - t0
        if Δt - exec.period ≥ 0.001 && !has_activity(exec)
          sleep(Δt - exec.period)
        else
          yield()
        end
        Δt = time() - t0
      end
    end

    @label out
    shutdown_children()
  end
end

function has_activity(exec::ExecutionMode)
  isempty(exec.state.recent_activity) && return false
  time() - last(exec.state.recent_activity).time < 3exec.period
end
