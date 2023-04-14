module ConcurrencyGraph

using CompileTraces
using Dictionaries
using Base: RefValue
using UUIDs: uuid4, UUID
using Reexport
@reexport using .Threads: nthreads, threadid
@reexport using ResultTypes: Result, unwrap, iserror, unwrap_error, @try

uuid() = uuid4()

include("forward.jl")
# include("lib/bijection.jl")
# include("lib/property_graph.jl")

include("messages.jl")
include("task_state.jl")
include("commands.jl")
include("error.jl")
include("ownership.jl")
include("execution.jl")
include("connection.jl")
# include("ack.jl")
include("spawn.jl")
include("taskgroup.jl")

@compile_traces verbose = false joinpath(@__DIR__, "precompilation_traces.jl")

export
  Message,
  send, trysend,
  manage_messages,

  Cancel, cancel, shutdown, schedule_shutdown, shutdown_scheduled,

  ExecutionMode, SingleExecution, LoopExecution,
  spawn, SpawnOptions, @spawn,
  Command,

  own, task_owner, children_tasks, shutdown_children,

  TaskError, PropagatedTaskError, ConcurrencyError, monitor_children,
  SUCCESS, FAILED, RECEIVER_DEAD, SHUTDOWN_RECEIVED, TIMEOUT,

  call, execute, tryexecute, Future, tryfetch, reset_mpi_state, istasksuccessful,

  TaskGroup
end
