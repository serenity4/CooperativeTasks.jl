using Test, ConcurrencyGraph, Graphs

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
    redirect_stdout(io) do
      f()
      sleep(0.1)
    end
    seekstart(io)
    @test read(io, String) == captured
  end
end

@testset "Concurrency" begin
  ConcurrencyGraph.init()
  exec = LoopExecution(0.1)
  t = @spawn exec()()
  @test shutdown(t)
  @test istasksuccessful(t)

  exec = LoopExecution(0.1)
  t1 = @spawn exec()()

  function pingpong(i)
    c = isodd(i) ? 'i' : 'o'
    println("P$(c)ng! ($i)")
    i + 1
  end

  test_capture_stdout(() -> send(t1, Message(Command(pingpong, 1; continuation = identity))), "Ping! (1)\n")
  @test shutdown(t1)
  @test istasksuccessful(t1)

  test_capture_stdout(manage_messages, "")

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
