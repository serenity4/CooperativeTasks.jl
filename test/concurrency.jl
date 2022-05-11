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
  g = ThreadGraph()
  th1 = Thread(g)
  th2 = Thread(g)
  @test nv(g) == 2
  @test !add_vertex!(g, th1)
  @test !add_vertex!(g, th2)
  @test add_edge!(g, th1, th2)
  @test channel(th1, th2) isa ConcurrencyGraph.Channel
  @test !has_edge(g, th2, th1)
  @test channel(th2, th1) isa ConcurrencyGraph.Channel
  @test has_edge(g, th2, th1)

  g = thread_graph()
  @test nv(g) == 1
  @test current_thread(g).taskref[] == current_task()

  g = thread_graph()
  exec = LoopExecution(0.1)
  th = Thread(exec(identity), g)
  @test add_edge!(g, current_thread(g), th)
  @test cancel(th)
  @test istasksuccessful(th.taskref[])

  g = thread_graph()
  exec = LoopExecution(0.1)
  th1 = Thread(exec(identity), g)

  function pingpong(i)
    c = isodd(i) ? 'i' : 'o'
    println("P$(c)ng! ($i)")
    i + 1
  end

  test_capture_stdout(() -> execute(Command(pingpong, th1, 1; continuation = identity)), "Ping! (1)\n")
  @test shutdown(th1)

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
