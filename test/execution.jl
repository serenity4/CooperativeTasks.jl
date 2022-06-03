using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks

ConcurrencyGraph.init()

include("task_utils.jl")

@testset "Execution modes" begin
  reinit()
  t = @spawn nothing
  @test t in children_tasks()
  wait(t)
  @test istasksuccessful(t)
  @test manage_messages() isa Any

  reinit()
  t = @spawn :looped nothing
  @test t in children_tasks()
  @test manage_messages() isa Any
  sleep(0.01)
  @test !istaskdone(t)
  shutdown_children()
  wait(t)
  @test istasksuccessful(t)
end
