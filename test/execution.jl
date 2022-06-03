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

  for exec in (LoopExecution(nothing), LoopExecution(0.01))
    reinit()
    t = @spawn exec nothing
    @test t in children_tasks()
    @test manage_messages() isa Any
    sleep(0.01)
    @test !istaskdone(t)
    shutdown_children()
    wait(t)
    @test istasksuccessful(t)

    t = @spawn exec error("Nooo!")
    @test t in children_tasks()
    sleep(0.1)
    @test_throws ChildFailedException manage_messages() isa Any
    @test istasksuccessful(t)
  end
end
