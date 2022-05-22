"""
List of tasks to be shutdown via a finalizer once the lifetime of `TaskGroup` expires.
"""
mutable struct TaskGroup
  tasks::Vector{Task}
  function TaskGroup(tasks = Task[])
    tasks = convert(Vector{Task}, tasks)
    finalizer(new(tasks)) do tg
      for task in tg.tasks
        @async shutdown(task)
      end
    end
  end
end

@forward TaskGroup.tasks (Base.push!,)
