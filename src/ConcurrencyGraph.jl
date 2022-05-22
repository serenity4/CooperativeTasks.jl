module ConcurrencyGraph

using Graphs
using Dictionaries
using Base: RefValue
using UUIDs: uuid4, UUID

uuid() = uuid4()

include("forward.jl")
include("lib/bijection.jl")
include("lib/property_graph.jl")
include("concurrency.jl")
include("error.jl")
include("ownership.jl")
include("execution.jl")
include("spawn.jl")
include("taskgroup.jl")

export BijectiveMapping,
  PropertyGraph,
  index,
  property,

  # Concurrency
  send, Message,
  manage_messages,
  ExecutionMode,
  LoopExecution,
  Cancel, cancel, shutdown,
  Command,
  @spawn,
  own, children_tasks

end
