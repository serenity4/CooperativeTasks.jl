struct BijectiveMapping{T1,T2}
  forward::Dictionary{T1,T2}
  backward::Dictionary{T2,T1}
end

BijectiveMapping{T1,T2}() where {T1,T2} = BijectiveMapping{T1,T2}(Dictionary(), Dictionary())
BijectiveMapping() = BijectiveMapping{Any,Any}()

function Base.convert(::Type{BijectiveMapping{T1,T2}}, bmap::BijectiveMapping{T3,T4}) where {T1,T2,T3,T4}
  BijectiveMapping(convert(Dictionary{T1,T2}, bmap.forward), convert(Dictionary{T2,T1}, bmap.backward))
end
Base.convert(::Type{BijectiveMapping{T1,T2}}, bmap::BijectiveMapping{T1,T2}) where {T1,T2} = bmap

function Base.insert!(bmap::BijectiveMapping{T1,T2}, key::T1, val::T2) where {T1,T2}
  haskey(bmap.forward, key) && error("The key $key is already present in the dictionary.")
  haskey(bmap.backward, val) && error("The value $val is already present in the dictionary.")
  insert!(bmap.forward, key, val)
  insert!(bmap.backward, val, key)
end

function Base.setindex!(bmap::BijectiveMapping{T1,T2}, val::T2, key::T1) where {T1,T2}
  delete!(bmap, key)
  insert!(bmap, key, val)
end
function Base.setindex!(bmap::BijectiveMapping{T1,T2}, val::T1, key::T2) where {T1,T2}
  delete!(bmap, key)
  insert!(bmap, key, val)
end

Base.insert!(bmap::BijectiveMapping{T1,T2}, key::T2, val::T1) where {T1,T2} = insert!(bmap, val, key)
Base.getindex(bmap::BijectiveMapping{T1}, key::T1) where {T1} = bmap.forward[key]
Base.getindex(bmap::BijectiveMapping{<:Any,T2}, key::T2) where {T2} = bmap.backward[key]
Base.get(bmap::BijectiveMapping, key, default) = haskey(bmap, key) ? bmap[key] : default
Base.haskey(bmap::BijectiveMapping{T1}, key::T1) where {T1,T2} = haskey(bmap.forward, key)
Base.haskey(bmap::BijectiveMapping{<:Any,T2}, key::T2) where {T2} = haskey(bmap.backward, key)
function Base.delete!(bmap::BijectiveMapping{T1}, key::T1) where {T1}
  delete!(bmap.backward, bmap.forward[key])
  delete!(bmap.forward, key)
end
function Base.delete!(bmap::BijectiveMapping{<:Any,T2}, key::T2) where {T2}
  delete!(bmap.forward, bmap.backward[key])
  delete!(bmap.backward, key)
end

function Dictionaries.sortkeys!(bmap::BijectiveMapping)
  sortkeys!(bmap.forward)
  sort!(bmap.backward)
end

@forward_methods BijectiveMapping field = :forward Base.pairs Base.iterate(_, args...)

function merge_unique!(dict, ds...)
  for d in ds
    for (k, v) in pairs(d)
      insert!(dict, k, v)
    end
  end
  dict
end
