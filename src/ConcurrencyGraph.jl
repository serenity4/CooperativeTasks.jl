module ConcurrencyGraph

using Dictionaries
using Base: RefValue
using UUIDs: uuid4, UUID
using Reexport
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

export
  Message,
  send, trysend,
  manage_messages,

  Cancel, cancel, shutdown,

  ExecutionMode,
  LoopExecution,
  Command,

  own, owner, children_tasks, shutdown_children,

  TaskError, PropagatedTaskError, ConcurrencyError, monitor_children,
  SUCCESS, FAILED, RECEIVER_DEAD, SHUTDOWN_RECEIVED, TIMEOUT,

  call, execute, tryexecute, Future, tryfetch, reset_all, istasksuccessful,

  TaskGroup,

  @spawn
end
