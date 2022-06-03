module ConcurrencyGraph

using Accessors: @set
using Graphs
using Dictionaries
using Base: RefValue
using UUIDs: uuid4, UUID

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
include("spawn.jl")
include("taskgroup.jl")

export send, Message,
  manage_messages,

  Cancel, cancel, shutdown,

  ExecutionMode,
  LoopExecution,
  Command,

  own, owner, children_tasks, shutdown_children,

  ChildFailedException,

  Result, is_success, status, value,

  call, execute, Future,

  @spawn
end
