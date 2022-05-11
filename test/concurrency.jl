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

@testset "Concurrency" begin
  g = ThreadGraph()
  th1 = Thread(g)
  th2 = Thread(g)
  @test nv(g) == 2
  @test !add_vertex!(g, th1)
  @test !add_vertex!(g, th2)
  @test add_edge!(g, th1, th2)

  g = thread_graph()
  @test nv(g) == 1
  exec = LoopExecution(0.1)
  th = Thread(exec(identity), g)
  @test add_edge!(g, current_thread(g), th)
  @test cancel(current_thread(g), th)
  @test istasksuccessful(th.taskref[])
end
