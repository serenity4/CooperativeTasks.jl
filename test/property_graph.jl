using Test, ConcurrencyGraph, Graphs

struct LabeledEdge
  src::Symbol
  dst::Symbol
end

Graphs.src(edge::LabeledEdge) = edge.src
Graphs.dst(edge::LabeledEdge) = edge.dst

@testset "Property graph" begin
  g = PropertyGraph{Int, SimpleDiGraph{Int}, Symbol, LabeledEdge}()
  @test nv(g) == 0
  @test add_vertex!(g, :a)
  @test nv(g) == 1
  @test add_vertex!(g, :b)
  @test !add_vertex!(g, :b)
  @test nv(g) == 2
  @test add_edge!(g, LabeledEdge(:a, :b))
  @test !add_edge!(g, LabeledEdge(:a, :b))
  @test !add_edge!(g, LabeledEdge(:does_not, :exist))
  @test ne(g) == 1
  @test index(g, :a) == 1
  @test index(g, :b) == 2
  @test_throws Exception index(g, :c)
  @test property(g, 1) == :a
  @test property(g, index(g, :a)) == :a
  @test index(g, property(g, 1)) == 1
  @test rem_edge!(g, LabeledEdge(:a, :b))
  @test !rem_edge!(g, LabeledEdge(:a, :b))
  @test rem_vertex!(g, :a)
  @test !rem_vertex!(g, :a)
  @test add_vertex!(g, :a)
  @test rem_vertex!(g, :a)
  @test !rem_edge!(g, LabeledEdge(:a, :b))
end
