precompile(Tuple{ConcurrencyGraph.var"##SingleExecution#32", Bool, Type{ConcurrencyGraph.SingleExecution}})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:start_threadid,), Tuple{Int64}}, Type{ConcurrencyGraph.SpawnOptions}})
precompile(Tuple{typeof(ConcurrencyGraph.spawn), Function, ConcurrencyGraph.SpawnOptions})
precompile(Tuple{ConcurrencyGraph.var"#_#10#11", Nothing, Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}}, Type{ConcurrencyGraph.Command}, Function})
precompile(Tuple{Type{ConcurrencyGraph.ConcurrencyError}, ConcurrencyGraph.StatusCode})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{ConcurrencyGraph.Message{T} where T, ConcurrencyGraph.ConcurrencyError}}, ConcurrencyGraph.ConcurrencyError})
precompile(Tuple{typeof(ConcurrencyGraph.reset_mpi_state)})
precompile(Tuple{ConcurrencyGraph.var"#30#31"{Array{ConcurrencyGraph.Condition, 1}}})
precompile(Tuple{typeof(Base.setproperty!), ConcurrencyGraph.Condition, Symbol, Bool})
precompile(Tuple{typeof(Base.get!), Type{Dictionaries.Dictionary{Base.UUID, ConcurrencyGraph.Message{T} where T}}, Base.IdDict{Any, Any}, Any})
precompile(Tuple{typeof(Base.get!), Type{Dictionaries.Dictionary{Task, ConcurrencyGraph.Connection}}, Base.IdDict{Any, Any}, Any})
precompile(Tuple{typeof(Base.get!), Type{Dictionaries.Dictionary{Task, ConcurrencyGraph.TaskState}}, Base.IdDict{Any, Any}, Any})
precompile(Tuple{typeof(ConcurrencyGraph.execution_mode), Symbol})
precompile(Tuple{Type{NamedTuple{(:execution_mode,), T} where T<:Tuple}, Tuple{ConcurrencyGraph.SingleExecution}})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:execution_mode,), Tuple{ConcurrencyGraph.SingleExecution}}, Type{ConcurrencyGraph.SpawnOptions}})
precompile(Tuple{typeof(Base.put!), Base.Channel{ConcurrencyGraph.Message{T} where T}, ConcurrencyGraph.Message{ConcurrencyGraph.Command}})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{ConcurrencyGraph.Message{T} where T, ConcurrencyGraph.ConcurrencyError}}, ConcurrencyGraph.Message{ConcurrencyGraph.Command}})
precompile(Tuple{typeof(ResultTypes.unwrap), ResultTypes.Result{ConcurrencyGraph.Message{T} where T, ConcurrencyGraph.ConcurrencyError}})
precompile(Tuple{typeof(ConcurrencyGraph.set_task_state), Task, ConcurrencyGraph.TaskState})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}}, ConcurrencyGraph.TaskState})
precompile(Tuple{typeof(ConcurrencyGraph.handle_error), ConcurrencyGraph.PropagatedTaskError})
precompile(Tuple{typeof(ConcurrencyGraph.istasksuccessful), Task})
precompile(Tuple{Type{ConcurrencyGraph.LoopExecution}, Float64})
precompile(Tuple{Type{NamedTuple{(:start_threadid, :allow_task_migration, :execution_mode), T} where T<:Tuple}, Tuple{Int64, Bool, ConcurrencyGraph.LoopExecution}})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:start_threadid, :allow_task_migration, :execution_mode), Tuple{Int64, Bool, ConcurrencyGraph.LoopExecution}}, Type{ConcurrencyGraph.SpawnOptions}})
precompile(Tuple{ConcurrencyGraph.var"#15#16", ConcurrencyGraph.Future})
precompile(Tuple{typeof(ConcurrencyGraph.shutdown_children)})
precompile(Tuple{typeof(Base.wait), ConcurrencyGraph.Condition})
precompile(Tuple{typeof(ConcurrencyGraph.schedule_shutdown)})
precompile(Tuple{ConcurrencyGraph.var"#6#7"{Task}})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}}, Bool})
precompile(Tuple{typeof(Base.put!), Base.Channel{ConcurrencyGraph.Message{T} where T}, ConcurrencyGraph.Message{ConcurrencyGraph.ReturnedValue}})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{ConcurrencyGraph.Message{T} where T, ConcurrencyGraph.ConcurrencyError}}, ConcurrencyGraph.Message{ConcurrencyGraph.ReturnedValue}})
precompile(Tuple{Type{ConcurrencyGraph.LoopExecution}, Nothing})
precompile(Tuple{typeof(ConcurrencyGraph.execution_mode), ConcurrencyGraph.LoopExecution})
precompile(Tuple{Type{NamedTuple{(:execution_mode,), T} where T<:Tuple}, Tuple{ConcurrencyGraph.LoopExecution}})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:execution_mode,), Tuple{ConcurrencyGraph.LoopExecution}}, Type{ConcurrencyGraph.SpawnOptions}})
precompile(Tuple{typeof(ConcurrencyGraph.execute), Function, Task})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}}, Int64})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:timeout,), Tuple{Int64}}, typeof(ConcurrencyGraph.tryfetch), ConcurrencyGraph.Future})
precompile(Tuple{ConcurrencyGraph.var"#23#24"{ConcurrencyGraph.Future, Dictionaries.Dictionary{Base.UUID, Any}}})
precompile(Tuple{typeof(Base.setindex!), Base.RefValue{Any}, ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}})
precompile(Tuple{typeof(ResultTypes.iserror), ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}})
precompile(Tuple{typeof(ResultTypes.unwrap), ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}})
precompile(Tuple{typeof(ConcurrencyGraph.execute), Function, Task, Vararg{Any}})
precompile(Tuple{ConcurrencyGraph.var"##execute#14", Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}}, typeof(ConcurrencyGraph.execute), Function, Vararg{Any}})
precompile(Tuple{typeof(ConcurrencyGraph.tryexecute), Function, Task, Int64})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:timeout,), Tuple{Int64}}, typeof(Base.fetch), ConcurrencyGraph.Future})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:continuation,), Tuple{Nothing}}, typeof(ConcurrencyGraph.execute), Function, Task})
precompile(Tuple{typeof(ResultTypes.unwrap_error), ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}})
precompile(Tuple{typeof(Base.getproperty), ConcurrencyGraph.TaskError, Symbol})
precompile(Tuple{typeof(ConcurrencyGraph.tryexecute), Function, Task})
precompile(Tuple{typeof(ResultTypes.unwrap_error), ResultTypes.Result{ConcurrencyGraph.Future, ConcurrencyGraph.ConcurrencyError}})
precompile(Tuple{typeof(Base.:(==)), ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.ConcurrencyError})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{ConcurrencyGraph.Future, String}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{ConcurrencyGraph.Future, String}, Int64, Int64})
precompile(Tuple{typeof(Base.fetch), ConcurrencyGraph.Future})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}}, ConcurrencyGraph.Future})
precompile(Tuple{typeof(ResultTypes.iserror), ConcurrencyGraph.Future})
precompile(Tuple{typeof(Base.sprint), Function, ConcurrencyGraph.PropagatedTaskError})
precompile(Tuple{typeof(Base.showerror), Base.GenericIOBuffer{Array{UInt8, 1}}, ConcurrencyGraph.PropagatedTaskError})
precompile(Tuple{typeof(Base.showerror), Base.GenericIOBuffer{Array{UInt8, 1}}, ConcurrencyGraph.ConcurrencyError, Array{Union{Ptr{Nothing}, Base.InterpreterIP}, 1}})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}}, Nothing})
precompile(Tuple{typeof(ConcurrencyGraph.task_states)})
precompile(Tuple{typeof(Base.convert), Type{ResultTypes.Result{Any, Union{ConcurrencyGraph.ConcurrencyError, ConcurrencyGraph.TaskError}}}, Dictionaries.Dictionary{Task, ConcurrencyGraph.TaskState}})
precompile(Tuple{Type{Pair{A, B} where B where A}, Task, ConcurrencyGraph.TaskState})
precompile(Tuple{typeof(Base.vect), Pair{Task, ConcurrencyGraph.TaskState}, Vararg{Pair{Task, ConcurrencyGraph.TaskState}}})
precompile(Tuple{typeof(Dictionaries.dictionary), Array{Pair{Task, ConcurrencyGraph.TaskState}, 1}})
precompile(Tuple{typeof(Base.:(==)), Dictionaries.Dictionary{Task, ConcurrencyGraph.TaskState}, Dictionaries.Dictionary{Task, ConcurrencyGraph.TaskState}})
precompile(Tuple{typeof(ConcurrencyGraph.tryexecute), Function, Task, Task, Vararg{Any}})
precompile(Tuple{ConcurrencyGraph.var"##tryexecute#12", Bool, Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}}, typeof(ConcurrencyGraph.tryexecute), Function, Task, Task, Vararg{Any}})
precompile(Tuple{Type{ConcurrencyGraph.Command}, Function, Task, Vararg{Any}})
precompile(Tuple{ConcurrencyGraph.var"#_#10#11", Nothing, Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}}, Type{ConcurrencyGraph.Command}, Function, Task, Vararg{Any}})
precompile(Tuple{typeof(Base.:(==)), ConcurrencyGraph.TaskState, ConcurrencyGraph.TaskState})
precompile(Tuple{typeof(Base.getproperty), ConcurrencyGraph.SpawnOptions, Symbol})
precompile(Tuple{Base.Fix1{typeof(Base.showerror), Base.IOStream}, ConcurrencyGraph.PropagatedTaskError})
