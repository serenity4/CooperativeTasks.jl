using CooperativeTasks, Test
using CooperativeTasks: owned_tasks

include("task_utils.jl")

@testset "Spawning tasks" begin
    @test_throws r"but only (.*) are available" spawn(Returns(nothing), SpawnOptions(start_threadid = 1000000000))
    @test_throws "≥ 1" spawn(Returns(nothing), SpawnOptions(start_threadid = 0))

    reset()

    t = @spawn begin
        sleep(0.5)
        error("Failed!")
    end
    sleep(0.1)
    @test istaskstarted(t)
    @test !istaskdone(t)
    @test t in owned_tasks()
    @test task_owner(t) == current_task()
    wait(t)
    @test_throws PropagatedTaskException manage_messages()
    @test istasksuccessful(t)

    t = @spawn error("Failed!")
    wait(t)
    @test istasksuccessful(t)
    @test_throws PropagatedTaskException manage_messages()

    @testset "Task migration" begin
        @assert nthreads() ≥ 2
        from = Int[]
        t = spawn(SpawnOptions(start_threadid = 2, allow_task_migration = false, execution_mode = LoopExecution(0.001))) do
            push!(from, threadid())
        end
        sleep(0.5)
        @test wait(shutdown_owned_tasks())
        @test all(==(2), from)

        from = [Int[] for _ in 1:nthreads()]
        for i in 1:nthreads()
            t = spawn(SpawnOptions(start_threadid = i, allow_task_migration = false, execution_mode = LoopExecution(0.001))) do
                push!(from[threadid()], i)
            end
        end
        sleep(0.5)
        @test wait(shutdown_owned_tasks())
        @test all(allequal, from)
    end
end;
