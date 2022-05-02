struct PropertyGraph{T,G<:AbstractGraph{T},V,E} <: AbstractGraph{T}
  graph::G
  vertex_properties::BijectiveMapping{T,V}
  edge_properties::BijectiveMapping{Edge{T},E}
end

@forward PropertyGraph.graph (Base.eltype, Graphs.edges, Graphs.edgetype, Graphs.has_edge, Graphs.has_vertex, Graphs.inneighbors, Graphs.ne, Graphs.nv, Graphs.outneighbors, Graphs.vertices, Graphs.is_directed)

function Graphs.add_edge!(p::PropertyGraph{<:Any,<:Any,<:Any,E}, edge::E) where {E}
  haskey(p.edge_properties, edge) && return false
  e = Edge(src(edge), dst(edge))
  added = add_edge!(p.graph, e)
  if added
    insert!(p.edge_properties, e, edge)
  end
  added
end

function Graphs.add_vertex!(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V}
  haskey(p.vertex_properties, vertex) && return false
  added = add_vertex!(p.graph)
  if added
    insert!(p.vertex_properties, nv(p.graph), vertex)
  end
  added
end

property(p::PropertyGraph, vertex::Integer) = p.vertex_properties[vertex]
property(p::PropertyGraph, edge::Edge) = p.edge_properties[edge]
property(p::PropertyGraph, src, dst) = p.edge_properties[Edge(src, dst)]
index(p::PropertyGraph{<:Any,<:Any,V}, vertex::V) where {V} = p.vertex_properties[vertex]
index(p::PropertyGraph{<:Any,<:Any,<:Any,E}, edge::E) where {E} = p.edge_properties[edge]
