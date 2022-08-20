using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks, Future

include("task_utils.jl")

@testset "Commands" begin
  reset_all()

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
end;
