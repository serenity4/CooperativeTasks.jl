using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks

include("task_utils.jl")

@testset "Spawning tasks" begin
    reinit()

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
    go[] = true
    wait(t)
    @test_throws ChildFailedException manage_messages()
    @test istasksuccessful(t)

    t = @spawn error("Failed!")
    wait(t)
    @test istasksuccessful(t)
    @test_throws ChildFailedException manage_messages()
end
