using CooperativeTasks, Test
using CooperativeTasks: children_tasks, Future

include("task_utils.jl")

@testset "Commands" begin
  reset_mpi_state()

  t = @spawn :looped nothing
  fut = execute(() -> 1 + 1, t)
  @test isa(fut, Future)
  ret = tryfetch(fut; timeout = 1)
  @test !iserror(ret)
  @test unwrap(ret) == 2
  @test !istaskdone(t)
  fut = execute(Base.Fix1(+, 1), t, 1)
  @test fetch(fut; timeout = 1) == 2
  fut = execute(() -> error("Oh no!"), t; continuation = nothing)
  err = unwrap_error(tryfetch(fut; timeout = 1))
  @test err isa TaskError && err.exc == ErrorException("Oh no!")
  @test wait(shutdown(t))
  @test unwrap_error(tryexecute(Returns(nothing), t)) == ConcurrencyError(RECEIVER_DEAD)

  @testset "Ping-pong example" begin
    function pingpong(i)
      c = isodd(i) ? 'i' : 'o'
      println("P$(c)ng! ($i)")
      i + 1
    end

    t = @spawn :looped nothing
    ret, captured = capture_stdout(() -> execute(pingpong, t, 1))
    @test fetch(ret) == 2
    @test captured == "Ping! (1)\n"

    t2 = @spawn :looped nothing

    function pingpong_continuation(i)
      !iserror(i) || return
      i = unwrap(i)
      i > 5 && return
      execute(pingpong, iseven(i) ? t : t2, i; continuation = pingpong_continuation)
    end

    fut, captured = capture_stdout(() -> execute(() -> Base.invokelatest(execute, pingpong, t2, 1; continuation = pingpong_continuation), t))
    @test captured ==
      """
      Ping! (1)
      Pong! (2)
      Ping! (3)
      Pong! (4)
      Ping! (5)
      """
    @test !iserror(fetch(fut))
    shutdown_children()
  end

  @testset "Proper shutdown while fetching a future" begin
    t = @spawn :looped nothing
    t2 = @spawn :single begin
      sleep(0.5)
      fetch(execute(() -> sleep(0.1), t))
    end
    sleep(0.1)
    @test wait(shutdown(t))
    @test istasksuccessful(t)
    wait(t2)
    @test istasksuccessful(t2)
    @test_throws "RECEIVER_DEAD" manage_messages()

    t = @spawn :looped nothing
    t2 = @spawn :single fetch(execute(() -> sleep(0.5), t))
    sleep(0.1)
    @test_throws "SHUTDOWN_RECEIVED" wait(shutdown(t2))
    sleep(0.1)
    @test istasksuccessful(t2)
    manage_messages()
    @test wait(shutdown(t))
    @test istasksuccessful(t)
  end
end;
