using Test, ConcurrencyGraph

@testset "Concurrency" begin
  g = ThreadGraph()
  t1 = Thread()
  t2 = Thread()
  @test add_vertex!(g, t1)
  @test add_vertex!(g, t2)
  @test add_edge!(g, t1, t2)
end
