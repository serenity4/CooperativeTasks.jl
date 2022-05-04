module ConcurrencyGraph

using Graphs
using Dictionaries
using Base: RefValue

include("forward.jl")
include("bijection.jl")
include("property_graph.jl")
include("concurrency.jl")

export BijectiveMapping,
  PropertyGraph,
  index,
  property,
  Thread,
  ThreadGraph

end
