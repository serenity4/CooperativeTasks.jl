using ConcurrencyGraph
using Test

@testset "ConcurrencyGraph.jl" begin
  include("bijection.jl")
  include("property_graph.jl")
end
