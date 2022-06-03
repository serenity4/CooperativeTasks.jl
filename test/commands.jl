using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks, Future

include("task_utils.jl")

@testset "Commands" begin
  reinit()

  t = @spawn :looped nothing
  fut = execute(() -> 1 + 1, t)
  @test isa(fut, Future)
  ret = fetch(fut, 1)
  @test is_success(ret)
  @test value(ret) == 2
  @test !istaskdone(t)
  fut = execute(Base.Fix1(+, 1), t, 1)
  @test value(fetch(fut, 1)) == 2
  fut = execute(() -> error("Oh no!"), t; continuation = nothing)
  ret = fetch(fut, 1)
  @test !is_success(ret)
  @test value(fetch(shutdown(t)))
end;
