using ConcurrencyGraph, Test
using ConcurrencyGraph: DEAD, ALIVE, state, task_states
using Dictionaries

include("task_utils.jl")

@testset "Monitoring" begin
  reset_all()

  t1 = Ref{Task}()
  t2 = Ref{Task}()

  t = @spawn begin
    t1[] = @spawn :looped nothing
    t2[] = @spawn :looped nothing
    monitor_children(; allow_failures = true)
  end

  sleep(0.2)
  @test value(fetch(execute(task_states, t1[]))) == dictionary([t => ALIVE, current_task() => ALIVE])
  @test wait(shutdown(t1[]))
  @test value(fetch(execute(state, t, t1[]))) == DEAD
  @test !istaskdone(t)
  @test wait(shutdown(t2[]))
  wait(t)
  @test istasksuccessful(t)

  t = @spawn begin
    t1[] = @spawn :looped nothing
    t2[] = @spawn :looped nothing
    monitor_children(; allow_failures = false)
  end

  sleep(0.2)
  @test wait(shutdown(t1[]))
  wait(t)
  wait(t2[])
  @test istasksuccessful(t2[])
  @test istasksuccessful(t)
end
