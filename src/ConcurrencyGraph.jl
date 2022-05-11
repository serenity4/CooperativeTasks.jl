module ConcurrencyGraph

using Graphs
using Dictionaries
using Base: RefValue
using UUIDs: uuid4, UUID

uuid() = uuid4()

include("forward.jl")
include("bijection.jl")
include("property_graph.jl")
include("concurrency.jl")

export BijectiveMapping,
  PropertyGraph,
  index,
  property,
  Thread,
  ThreadGraph,
  ExecutionMode,
  LoopExecution,
  cancel, shutdown,
  thread_graph,
  current_thread,
  threads,
  Command,
  execute,
  channel

end
