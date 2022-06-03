using Test, ConcurrencyGraph, Graphs
using ConcurrencyGraph: owner, own

function test_capture_stdout(f, captured)
  mktemp() do _, io
    withenv("JULIA_DEBUG" => "") do
      redirect_stdout(io) do
        f()
        sleep(0.1)
      end
      seekstart(io)
      @test read(io, String) == captured
    end
  end
end

@testset "Concurrency" begin
  reinit()
  t = @spawn nothing
  @test shutdown(t)
  @test istasksuccessful(t)

  t = @spawn do_nothing()

  function pingpong(i)
    c = isodd(i) ? 'i' : 'o'
    println("P$(c)ng! ($i)")
    i + 1
  end

  test_capture_stdout(() -> send(t, Command(pingpong, 1; continuation = identity)), "Ping! (1)\n")
  @test shutdown(t)
  @test istasksuccessful(t)

  test_capture_stdout(manage_messages, "")

  @testset "Error reporting" begin
    buggy_code() = error("Bug!")
    t = @spawn do_nothing()
    fetch(call(buggy_code, t), 0.1, 0)
    @test_throws ChildFailedException manage_messages()
    @test istasksuccessful(t)

    shutdown_children()
    manage_messages()

    t2 = Ref{Task}()
    t1 = @spawn begin
      t2[] = @spawn buggy_code()
      do_nothing()
    end
    sleep(0.1)
    @test istasksuccessful(t1)
    @test istasksuccessful(t2)
    @test fetch(call(owner, t2[]), 5, 0) == t1
    @test t1.result isa ChildFailedException
  end

  # Wait for better logging and error reporting before implementing these more complete example tests.

  # g = thread_graph()
  # exec = LoopExecution(0.1)
  # th1 = Thread(exec(identity), g)
  # th2 = Thread(exec(identity), g)

  # function pingpong_continuation(i)
  #   i > 5 && return
  #   execute(Command(pingpong, iseven(i) ? th1 : th2, i; continuation = pingpong_continuation))
  # end

  # execute(Command(() -> execute(Command(pingpong, th2, 1; continuation = pingpong_continuation)), th1))
  # sleep(1)
  # @test cancel(th1)
  # @test cancel(th2)
  # @test istasksuccessful(th1.taskref[])
  # @test istasksuccessful(th2.taskref[])
end
