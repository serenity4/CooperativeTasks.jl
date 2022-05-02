module ConcurrencyGraph

using Graphs
using Dictionaries

include("forward.jl")
include("bijection.jl")
include("property_graph.jl")
include("concurrency.jl")

export PropertyGraph, BijectiveMapping, Thread

end
