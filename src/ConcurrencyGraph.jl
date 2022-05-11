module ConcurrencyGraph

using Graphs
using Dictionaries
using Base: RefValue
using UUIDs: uuid5, UUID

uuid() = uuid5()

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
  cancel,
  thread_graph,
  current_thread,
  threads

end
