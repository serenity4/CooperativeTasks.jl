struct PropertyGraph{T,G<:AbstractGraph{T},V,E} <: AbstractGraph{T}
  graph::G
  vertex_properties::BijectiveMapping{T,V}
  edge_properties::BijectiveMapping{Edge{T},E}
end

PropertyGraph{T,G,V,E}() where {T,G,V,E} = PropertyGraph{T,G,V,E}(G(), BijectiveMapping{T,V}(), BijectiveMapping{Edge{T},E}())

@forward PropertyGraph.graph (Base.eltype, Graphs.edges, Graphs.edgetype, Graphs.has_edge, Graphs.has_vertex, Graphs.inneighbors, Graphs.ne, Graphs.nv, Graphs.outneighbors, Graphs.vertices, Graphs.is_directed)

function Graphs.add_edge!(p::PropertyGraph{<:Any,<:Any,V,E}, edge::E) where {V,E}
  haskey(p.edge_properties, edge) && return false
  s = src(edge)::V
  d = dst(edge)::V
  (!haskey(p.vertex_properties, s) || !haskey(p.vertex_properties, d)) && return false
  e = Edge(p.vertex_properties[s], p.vertex_properties[d])
  add_edge!(p.graph, e) || return false
  insert!(p.edge_properties, e, edge)
  true
end

function Graphs.add_vertex!(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V}
  haskey(p.vertex_properties, vertex) && return false
  add_vertex!(p.graph) || return false
  insert!(p.vertex_properties, nv(p.graph), vertex)
  true
end

function Graphs.rem_edge!(p::PropertyGraph{<:Any,<:Any,<:Any,<:E}, e::E) where {E}
  haskey(p.edge_properties, e) || return false
  rem_edge!(p.graph, p.edge_properties[e]) || return false
  delete!(p.edge_properties, e)
  true
end

function Graphs.rem_vertex!(p::PropertyGraph{<:Any,<:Any,V}, v::V) where {V}
  haskey(p.vertex_properties, v) || return false
  i = p.vertex_properties[v]
  for src in inneighbors(p, i)
    rem_edge!(p, property(g, src), v)
  end
  for dst in outneighbors(p, i)
    rem_edge!(p, v, property(g, dst))
  end
  rem_vertex!(p.graph, i) || return false
  delete!(p.vertex_properties, v)
  if i ≠ 1 + nv(p)
    p.vertex_properties[property(p, 1 + nv(p))] = i
  end
  true
end

property(p::PropertyGraph, vertex::Integer) = p.vertex_properties[vertex]
property(p::PropertyGraph, edge::Edge) = p.edge_properties[edge]
property(p::PropertyGraph, src, dst) = p.edge_properties[Edge(src, dst)]
index(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V} = p.vertex_properties[vertex]
index(p::PropertyGraph{<:Any,<:Any,<:Any,E}, edge::E) where {E} = p.edge_properties[edge]
