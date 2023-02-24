using ConcurrencyGraph, Test
using ConcurrencyGraph: DEAD, ALIVE, state, task_states, TLS_CHILDREN_TASKS
using Dictionaries

include("task_utils.jl")

@testset "Monitoring" begin
  reset_all()

  t1 = Ref{Task}()
  t2 = Ref{Task}()

  # Situation 1:
  # Two children tasks get spawned, one will be shutdown.
  # We test that the monitoring will continue until all tasks are dead.
  t = @spawn begin
    t1[] = @spawn :looped nothing
    t2[] = @spawn :looped nothing
    monitor_children(; allow_failures = true)
  end

  sleep(0.2)
  @test fetch(execute(task_states, t1[])) == dictionary([t => ALIVE, current_task() => ALIVE])
  @test wait(shutdown(t1[]))
  @test fetch(execute(state, t, t1[])) == DEAD
  @test !istaskdone(t)
  @test wait(shutdown(t2[]))
  wait(t)
  @test istasksuccessful(t)
  @test isempty(Base.get_task_tls(t)[TLS_CHILDREN_TASKS])

  # Situation 2:
  # Same as situation 1, but we test that the monitoring stops at the death of task 1.
  t = @spawn begin
    t1[] = @spawn :looped nothing
    t2[] = @spawn :looped nothing
    monitor_children()
  end

  sleep(0.2)
  @test wait(shutdown(t1[]))
  wait(t)
  @test istasksuccessful(t)
  @test isempty(Base.get_task_tls(t)[TLS_CHILDREN_TASKS])

  # Situation 3:
  # One of the tasks has failed before the monitoring even happened.
  # We want to make sure the monitoring stops and does not throw any exception (only show it).
  t, captured = capture_stdout(() -> @spawn begin
    t1[] = @spawn error("Oh no!")
    t2[] = @spawn :looped nothing
    sleep(0.2)
    monitor_children()
  end)

  sleep(0.2)
  @test startswith(captured, "PropagatedTaskError")
  @test istasksuccessful(t)
  @test isempty(Base.get_task_tls(t)[TLS_CHILDREN_TASKS])
end;
