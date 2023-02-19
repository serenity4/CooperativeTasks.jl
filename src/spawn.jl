"""
Options for spawning tasks with [`spawn`](@ref).
"""
Base.@kwdef struct SpawnOptions
  """
  [`ExecutionMode`](@ref) used for running the task.

  See [`LoopExecution`](@ref), [`SingleExecution`](@ref)
  """
  execution_mode::Union{LoopExecution,SingleExecution} = SingleExecution()
  """
  Optional thread ID to start the task on.

  If task migration is disabled, then the task will execute on this thread during its entire lifespan.
  If set to `nothing` (default), then the starting thread is the same as the thread launching the task.

  !!! warning
      If task migration is disabled, and no start thread ID has been set, the task will run similarly to an `@async`-spawned
      task and execution will never occur in parallel between the spawning task and the spawned task.
  """
  start_threadid::Union{Nothing,Int} = nothing
  """
  Allow tasks to migrate between Julia threads.

  This makes it reliable to use `Threads.threadid()` as an index from this task, for example enabling the pattern

  ```julia
  const results = [Int[] for i in 1:Threads.nthreads()]

  # ...
  # Spawn a bunch of tasks.
  # ...
  # Execute code like the following from these tasks:
  push!(results[Threads.threadid()], rand())
  ```

  Disabling this can be useful when e.g. C libraries rely on functions to be executed in the same thread in which
  some library-defined context has been created, as can be the case for graphics API such as Vulkan or OpenGL.
  """
  allow_task_migration::Bool = true
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

execution_mode(mode::Symbol) = mode == :single ? SingleExecution() : mode == :looped ? LoopExecution(nothing) : error("Unknown execution mode '$mode'")
execution_mode(mode::ExecutionMode) = mode

"""
Spawn the function `f` on a new task.

See also: [`SpawnOptions`](@ref)
"""
function spawn(f, options::SpawnOptions)
  task = Task(options.execution_mode(f))

  # Note: this is not concurrent, be careful to not schedule the task for execution before we are done with `tls`.
  tls = Base.get_task_tls(task)
  tls[:task_owner] = current_task()
  set!(error_handlers(), task, throw)
  tls[:mpi_channel] = Channel{Message}(Inf)
  tls[:mpi_task_states] = dictionary([current_task() => ALIVE])
  set_task_state(task, ALIVE)

  # List spawned task as child of the current task.
  push!(children_tasks(), task)

  task.sticky = !options.allow_task_migration
  !isnothing(options.start_threadid) && ccall(:jl_set_task_tid, Cvoid, (Any, Cint), task, options.start_threadid)

  # Support use with `@sync` blocks.
  @eval $(Expr(:islocal, SYNC_VARNAME)) && put!($SYNC_VARNAME, task)

  schedule(task)
  task
end
