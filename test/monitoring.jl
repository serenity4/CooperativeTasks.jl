using ConcurrencyGraph, Test
using ConcurrencyGraph: DEAD, state

include("task_utils.jl")

@testset "Monitoring" begin
  reinit()

  t1 = Ref{Task}()
  t2 = Ref{Task}()

  t = @spawn begin
    t1[] = @spawn :looped nothing
    t2[] = @spawn :looped nothing
    monitor_children()
  end

  sleep(0.2)
  @test value(fetch(shutdown(t1[])))
  @test value(fetch(execute(state, t, t1[]))) == DEAD
  @test !istaskdone(t)
  @test value(fetch(shutdown(t2[])))
  wait(t)
  @test istasksuccessful(t)

  t = @spawn begin
    t1[] = @spawn :looped nothing
    t2[] = @spawn :looped nothing
    monitor_children(; allow_failures = false)
  end

  sleep(0.2)
  @test value(fetch(shutdown(t1[])))
  wait(t)
  wait(t2[])
  @test istasksuccessful(t2[])
  @test istasksuccessful(t)
end
