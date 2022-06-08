using ConcurrencyGraph, Test
using ConcurrencyGraph: children_tasks

include("task_utils.jl")

@testset "Spawning tasks" begin
    reset_all()

    t = @spawn begin
        sleep(0.5)
        error("Failed!")
    end
    sleep(0.1)
    @test istaskstarted(t)
    @test !istaskdone(t)
    @test t in children_tasks()
    @test task_owner(t) == current_task()
    wait(t)
    @test_throws ChildFailedException manage_messages()
    @test istasksuccessful(t)

    t = @spawn error("Failed!")
    wait(t)
    @test istasksuccessful(t)
    @test_throws ChildFailedException manage_messages()
end;
