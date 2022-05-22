using Test, ConcurrencyGraph, Graphs
using ConcurrencyGraph: ChildFailedException

ENV["JULIA_DEBUG"] = "ConcurrencyGraph"
ENV["JULIA_DEBUG"] = ""

function istasksuccessful(task::Task)
  !istaskfailed(task) && istaskdone(task) && return true
  if istaskdone(task)
    if task._isexception
      if task.result isa Exception
        @error "Task was not successful:" exception = (task.result::Exception, task.backtrace)
      end
      false
    else
      true
    end
  end

  false
end

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
  ConcurrencyGraph.init()
  exec = LoopExecution(0.1)
  do_nothing = exec()
  t = @spawn do_nothing()
  @test shutdown(t)
  @test istasksuccessful(t)

  t = @spawn do_nothing()

  function pingpong(i)
    c = isodd(i) ? 'i' : 'o'
    println("P$(c)ng! ($i)")
    i + 1
  end

  test_capture_stdout(() -> send(t, Message(Command(pingpong, 1; continuation = identity))), "Ping! (1)\n")
  @test shutdown(t)
  @test istasksuccessful(t)

  test_capture_stdout(manage_messages, "")

  @testset "Error reporting" begin
    buggy_code = () -> error("Bug!")
    t = @spawn exec(buggy_code)()
    @test_throws ChildFailedException manage_messages()
    @test istasksuccessful(t)
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
