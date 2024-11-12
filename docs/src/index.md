```@meta
CurrentModule = CooperativeTasks
```

# CooperativeTasks

[CooperativeTasks](https://github.com/serenity4/CooperativeTasks.jl) facilitates working with long-running tasks by adding mechanisms for task spawning, code execution, monitoring, and error reporting.

This package defines a new [`@spawn`](@ref) macro, with several options to control task execution. For example, a task may be started on a specific thread, with task migration disabled to keep the task running on that specific thread.

Most of the functionality defined in this package relies on inter-task communication using [channels](https://docs.julialang.org/en/v1/manual/asynchronous-programming/#Communicating-with-Channels), with a protocol based on [message passing](https://en.wikipedia.org/wiki/Message_passing).

A core paradigm behind this functionality is the handling of concurrency via sequential operations.
While certain procedures use parallel execution for speed, there are environments that are inherently concurrent but without the need to rely on parallelism. Databases are a good example of this; if one has a database exposed over a network, and multiple applications need to perform read and write operations on the contents of this database concurrently, the best solution is to asynchronously queue these requests and wait for a database server to process them. It is a lot easier to request a unit to carry out a series of operations than it is to concurrently execute them safely. This shifts the burden of concurrency safety concerns to the queuing of requests instead of their execution, which is significantly easier.

```@index
```

```@autodocs
Modules = [CooperativeTasks]
```
