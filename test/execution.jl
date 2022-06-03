using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks, Future

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

    # Normal operations.
    t = @spawn exec nothing
    @test t in children_tasks()
    sleep(0.1)
    @test manage_messages() isa Any
    @test !istaskdone(t)
    shutdown_children()
    wait(t)
    @test istasksuccessful(t)

    # Graceful error handling.
    t = @spawn exec error("Nooo!")
    @test t in children_tasks()
    sleep(0.1)
    @test_throws ChildFailedException manage_messages() isa Any
    @test istasksuccessful(t)

    # Cancellation.
    t = @spawn exec nothing
    # Wait for task to start on slow systems.
    sleep(0.05)
    manage_messages()
    fut = shutdown(t)
    @test isa(fut, Future)
    ret = fetch(fut)
    @test is_success(ret) && value(ret) === true
    # Wait for task to exit.
    sleep(0.05)
    @test istaskdone(t)
  end
end
