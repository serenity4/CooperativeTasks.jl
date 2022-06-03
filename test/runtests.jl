using ConcurrencyGraph
using Test, SafeTestsets

testfile(filename) = joinpath(@__DIR__, filename)

TEST_FILES = [
  "bijection.jl",
  "property_graph.jl",
  "spawn.jl",
  "execution.jl",
]

function test(file::AbstractString)
  @info "Testing $file..."
  path = joinpath(@__DIR__, file)
  @eval @time @safetestset $file begin
    include($path)
  end
end

test(files::AbstractVector) = @testset "ConcurrencyGraph.jl" begin
  foreach(test, files)
end

test(TEST_FILES);
