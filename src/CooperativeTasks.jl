module CooperativeTasks

using DocStringExtensions
using CompileTraces
using Dictionaries
using Base: RefValue
using UUIDs: uuid4, UUID
using Reexport
using PrecompileTools
using CompileTraces
@reexport using .Threads: nthreads, threadid
@reexport using ResultTypes: Result, unwrap, iserror, unwrap_error, @try

@template FUNCTIONS =
  """
  $(DOCSTRING)
  $(METHODLIST)
  """

@template (METHODS, MACROS) =
  """
  $(DOCSTRING)
  $(TYPEDSIGNATURES)
  """

@template TYPES =
  """
  $(DOCSTRING)
  $(TYPEDEF)
  $(TYPEDFIELDS)
  """


uuid() = uuid4()

include("messages.jl")
include("communication.jl")
include("task_state.jl")
include("commands.jl")
include("error.jl")
include("ownership.jl")
include("execution.jl")
include("spawn.jl")

@compile_workload @compile_traces "precompilation_traces.jl"

export
  Message, manage_messages, manage_critical_messages,

  send, trysend,

  shutdown, cancel, schedule_shutdown, shutdown_scheduled,

  Command, execute, tryexecute,

  Future, fetch, tryfetch,

  own, task_owner, owned_tasks, shutdown_owned_tasks, monitor_owned_tasks,

  spawn, SpawnOptions, @spawn,
  SingleExecution, LoopExecution,

  SUCCESS, FAILED, RECEIVER_DEAD, SHUTDOWN_RECEIVED, TIMEOUT,
  ExecutionError, PropagatedTaskException, TaskException,
  istasksuccessful
end
