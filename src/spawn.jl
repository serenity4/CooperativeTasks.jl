"""
Options for spawning tasks with [`spawn`](@ref).
"""
Base.@kwdef struct SpawnOptions
  """
  Specifies how the task should be run, via a [`SingleExecution`](@ref) or [`LoopExecution`](@ref) structure.
  """
  execution_mode::Union{LoopExecution,SingleExecution} = SingleExecution()
  """
  Optional 1-based thread ID to start the task on.

  If task migration is disabled, then the task will execute on this thread during its entire lifespan.
  If set to `nothing` (default), then the starting thread is the same as the thread launching the task.

  !!! warning
      If task migration is disabled, and no start thread ID has been set, the task will run similarly to an `@async`-spawned
      task and execution will never occur in parallel between the spawning task and the spawned task.
  """
  start_threadid::Union{Nothing,Int} = nothing
  """
  Disallow tasks to migrate between Julia threads (`false` by default).

  When set to `false`, this corresponds to the behavior of `@async`, and when set to `true`, to the behavior of `Threads.@spawn`.

  Preventing task migration enables the use of `Threads.threadid()` as an index from the spawned tasks. For example, consider the following pattern:

  ```julia
  const results = [Int[] for i in 1:Threads.nthreads()]

  # ...
  # Spawn a bunch of tasks.
  # ...
  # Execute code like the following from these tasks:
  push!(results[Threads.threadid()], rand())
  ```

  This pattern requires `Threads.threadid()` to be constant over the entire lifespan of the tasks, which requires task migration to be disabled.

  Disabling task migration can also be useful when e.g. C libraries rely on functions to be executed in the same thread in which some library-defined context has been created, as can be the case for graphics API such as Vulkan or OpenGL.
  """
  disallow_task_migration::Bool = false
end

"Variable used for `Base.@sync` blocks."
const SYNC_VARNAME = Base.sync_varname

macro spawn(mode, ex)
  quote
    options = SpawnOptions(
      execution_mode = execution_mode($(esc(mode))),
    )
    spawn(() -> $(esc(ex)), options)
  end
end

macro spawn(ex) :(@spawn :single $(esc(ex))) end

"""
    @spawn [options] \$ex
    @spawn begin ... end
    @spawn :single begin ... end
    @spawn :looped begin ... end

Convenience macro to spawn a task via [`spawn`](@ref), defining a closure over `ex` as the function to be executed by the task.
"""
var"@spawn"

execution_mode(mode::Symbol) = mode == :single ? SingleExecution() : mode == :looped ? LoopExecution(nothing) : error("Unknown execution mode '$mode'")
execution_mode(mode::Union{SingleExecution, LoopExecution}) = mode

"""
Spawn a new task executing the function `f`.

!!! note
    Depending on the `execution_mode` parameter of the provided [`SpawnOptions`](@ref),
    `f()` may be executed multiple times.
"""
function spawn(f, options::SpawnOptions)
  check_validity(options)
  task = Task(options.execution_mode(f))

  # Note: this is not concurrent, be careful to not schedule the task for execution before we are done with `tls`.
  tls = Base.get_task_tls(task)
  tls[TLS_TASK_OWNER] = current_task()
  set!(error_handlers(), task, throw)
  tls[TLS_CHANNEL] = Channel{Message}(Inf)
  tls[TLS_TASK_STATES] = dictionary([current_task() => ALIVE])
  set_task_state(task, ALIVE)

  # List spawned task as child of the current task.
  push!(owned_tasks(), task)

  task.sticky = options.disallow_task_migration
  !isnothing(options.start_threadid) && ccall(:jl_set_task_tid, Cvoid, (Any, Cint), task, options.start_threadid - 1)

  # Support use with `@sync` blocks.
  @eval $(Expr(:islocal, SYNC_VARNAME)) && put!($SYNC_VARNAME, task)

  schedule(task)
  task
end

function check_validity(options::SpawnOptions)
  if !isnothing(options.start_threadid)
    options.start_threadid < 1 && throw(ArgumentError("If provided, the start thread ID must be ≥ 1."))
    options.start_threadid > nthreads() && error("A start thread ID of $(options.start_threadid) was provided, but only $(nthreads()) are available.")
  end
end
