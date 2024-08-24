using CooperativeTasks, Test

@testset "Bijection" begin
  d = BijectiveMapping{Symbol,String}()
  insert!(d, :a, "a")
  insert!(d, "b", :b)
  @test_throws ErrorException insert!(d, :a, "a")
  @test_throws ErrorException insert!(d, "a", :c)
  @test_throws ErrorException insert!(d, :c, "a")
  @test !haskey(d, :c)
  @test haskey(d, :a)
  @test haskey(d, "a")
  @test haskey(d, :b)
  @test haskey(d, "b")
  @test d[:a] == "a"
  @test d["a"] == :a
  @test isnothing(get(d, "c", nothing))
  @test isnothing(get(d, :c, nothing))
  @test get(d, :a, nothing) == "a"
  delete!(d, :a)
  @test !haskey(d, :a)
  @test !haskey(d, "a")
  @test isnothing(get(d, :a, nothing))
  @test d[:b] == "b"
  d[:b] = "c"
  @test d[:b] == "c"
  @test !haskey(d, "b")
  d["c"] = :d
  @test !haskey(d, :b)
  @test d[:d] == "c"
end;
