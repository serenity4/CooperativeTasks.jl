using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks

ConcurrencyGraph.init()
# ConcurrencyGraph.manage_messages()

include("task_utils.jl")

@testset "Spawning tasks" begin
    go = Ref(false)
    t = @spawn begin
        sleep(0.5)
        error("Failed!")
    end
    sleep(0.1)
    @test istaskstarted(t)
    @test !istaskdone(t)
    @test t in children_tasks()
    @test task_owner(t) == current_task()
    @test_throws ChildFailedException begin
        go[] = true
        wait(t)
        manage_messages()
    end
    @test istasksuccessful(t)

    @test_throws ChildFailedException begin
        t = @spawn error("Failed!")
        wait(t)
        manage_messages()
    end
    @test istasksuccessful(t)
end
