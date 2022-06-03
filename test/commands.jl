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

  @testset "Ping-pong example" begin
    function test_capture_stdout(f, captured)
      ret = nothing
      mktemp() do _, io
        withenv("JULIA_DEBUG" => "") do
          redirect_stdout(io) do
            ret = f()
            [sleep(0.1) for _ in 1:5]
          end
          seekstart(io)
          @test read(io, String) == captured
        end
      end
      ret
    end

    function pingpong(i)
      c = isodd(i) ? 'i' : 'o'
      println("P$(c)ng! ($i)")
      i + 1
    end

    t = @spawn :looped nothing
    test_capture_stdout(() -> execute(pingpong, t, 1), "Ping! (1)\n")

    t2 = @spawn :looped nothing

    function pingpong_continuation(i)
      is_success(i) || return
      i = value(i)
      i > 5 && return
      execute(pingpong, iseven(i) ? t : t2, i; continuation = pingpong_continuation)
    end

    fut = test_capture_stdout(() -> execute(() -> Base.invokelatest(execute, pingpong, t2, 1; continuation = pingpong_continuation), t),
      """
      Ping! (1)
      Pong! (2)
      Ping! (3)
      Pong! (4)
      Ping! (5)
      """)
    @test is_success(fetch(fut))
    shutdown_children()
  end
end;
