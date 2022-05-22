mutable struct PropertyGraph{T,G<:AbstractGraph{T},V,E} <: AbstractGraph{T}
  graph::G
  vertex_properties::BijectiveMapping{T,V}
  edge_properties::BijectiveMapping{Edge{T},E}
end

PropertyGraph{T,G,V,E}() where {T,G,V,E} = PropertyGraph{T,G,V,E}(G(), BijectiveMapping{T,V}(), BijectiveMapping{Edge{T},E}())

@forward PropertyGraph.graph (Base.eltype, Graphs.edges, Graphs.edgetype, Graphs.inneighbors, Graphs.ne, Graphs.nv, Graphs.outneighbors, Graphs.vertices, Graphs.is_directed)

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

Graphs.add_edge!(p::PropertyGraph{<:Any,<:Any,V,E}, src::V, dst::V) where {V,E} = add_edge!(p, E(src, dst))

function Graphs.add_vertex!(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V}
  haskey(p.vertex_properties, vertex) && return false
  add_vertex!(p.graph) || return false
  insert!(p.vertex_properties, nv(p.graph), vertex)
  true
end

function Graphs.rem_edge!(p::PropertyGraph{<:Any,<:Any,<:Any,<:E}, edge::E) where {E}
  haskey(p.edge_properties, edge) || return false
  rem_edge!(p.graph, p.edge_properties[edge]) || return false
  delete!(p.edge_properties, edge)
  true
end

function Graphs.rem_vertex!(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V}
  haskey(p.vertex_properties, vertex) || return false
  i = p.vertex_properties[vertex]
  for src in inneighbors(p, i)
    rem_edge!(p, property(g, src), vertex)
  end
  for dst in outneighbors(p, i)
    rem_edge!(p, vertex, property(g, dst))
  end
  rem_vertex!(p.graph, i) || return false
  delete!(p.vertex_properties, vertex)
  if i ≠ 1 + nv(p)
    p.vertex_properties[property(p, 1 + nv(p))] = i
  end
  true
end

edge(p::PropertyGraph{<:Any,<:Any,V}, src::V, dst::V) where {V} = property(p, Edge(index(p, src), index(p, dst)))
Graphs.has_edge(p::PropertyGraph{<:Any,<:Any,<:Any,E}, edge::E) where {E} = haskey(p.edge_properties, edge)
Graphs.has_edge(p::PropertyGraph, edge::Edge) = has_edge(p.graph, edge)
Graphs.has_edge(p::PropertyGraph{<:Any,<:Any,V}, src::V, dst::V) where {V} = has_vertex(p, src) && has_vertex(p, dst) && has_edge(p.graph, index(p, src), index(p, dst))
Graphs.has_edge(p::PropertyGraph{T}, src::T, dst::T) where {T} = has_edge(p.graph, src, dst)
Graphs.has_vertex(p::PropertyGraph{T}, vertex::T) where {T} = has_vertex(p.graph, vertex)
Graphs.has_vertex(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V} = haskey(p.vertex_properties, vertex)

property(p::PropertyGraph{T}, vertex::T) where {T} = p.vertex_properties[vertex]
property(p::PropertyGraph, edge::Edge) = p.edge_properties[edge]
property(p::PropertyGraph{T}, src::T, dst::T) where {T} = p.edge_properties[Edge(src, dst)]
property(p::PropertyGraph{<:Any,<:Any,V}, src::V, dst::V) where {V} = property(p, index(p, src), index(p, dst))
index(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V} = p.vertex_properties[vertex]
index(p::PropertyGraph{<:Any,<:Any,<:Any,E}, edge::E) where {E} = p.edge_properties[edge]

vertex_properties(p::PropertyGraph) = values(p.vertex_properties)
edge_properties(p::PropertyGraph) = values(p.edge_properties)
