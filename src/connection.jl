@enum ConnectionState::Int8 begin
  INITIALIZATION = 1
  ESTABLISHED = 2
  LOST = 3
end

"The connection has been initialized."
INITIALIZATION

"The connection has been established and is nominal."
ESTABLISHED

"The connection was established then lost, due to a failure from either end."
LOST

"""
Connection established with a peer, from a task-local perspective.
"""
struct Connection
  "The peer we are connected to."
  peer::Task
  "Whether the connection was initiated by the peer."
  initiated_by_peer::Bool
  "The state of the connection."
  state::ConnectionState
end
connection(peer::Task) = get(connections(), peer, nothing)

connection_state(peer::Task) = @something(connection(peer), return nothing).state

function set_connection_state(peer::Task, state::ConnectionState)
  conn = connection(peer)
  isnothing(conn) && return
  set!(connections(), peer, ConnectionState(state.peer, state.initiated_by_peer, state))
end

struct ConnectionRequest end

function connect(peer::Task)
  trysend(peer, ConnectionRequest())
end
