struct Ack
  uuid::UUID
end

function process_message(m::Message{Ack})
  d = acks()
  (; uuid) = m.payload
  if !haskey(d, uuid)
    @warn "Received unexpected ack for message $(uuid)"
  else
    prev_ack = d[uuid]
    !prev_ack || return @warn "Duplicate ack received for message $(uuid)"
    d[uuid] = true
  end
end

function wait_ack(uuid::UUID; timeout::Real = 5, sleep_time::Real = 0.001)
  success = wait_timeout(timeout, sleep_time) do
    manage_messages()
    ack_received(uuid)
  end
  !success && @warn "Timed out while waiting for ack after $timeout seconds"
  success
end

function trysend_ack(task_or_ch::Union{Task,Channel}, m::Message; wait_ack = true, timeout::Real = 5, sleep_time::Real = 0.001)
  m.ack[] = true
  insert!(acks(), m.uuid, false)
  trysend(task_or_ch, m)
  _wait(; timeout::Real = timeout, sleep_time::Real = sleep_time) = @__MODULE__().wait_ack(m.uuid; timeout, sleep_time)
  wait_ack && return _wait()
  _wait
end
