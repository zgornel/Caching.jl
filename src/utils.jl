# Additional constructors
DiskCache(mc::MemoryCache{T, I, O};
		  filename::String = _generate_cache_filename(mc.name)) where {T, I, O} =
    DiskCache(filename, deepcopy(mc), Dict{I, Tuple{Int, Int}}())


MemoryCache(dc::DiskCache) = deepcopy(dc.memcache)


#
function cachesync!(dc::T) where T<:DiskCache
    # TODO(Corneliu) Implenmentation
    # if file does not exist
    #   dump
    # else (if file/path does exists)
    #
    #   create directory
    #   create file,
end


macro cachesync!(dc)
    # TODO(Corneliu) Implenmentation
end


# Function that dumps the MemoryCache cache to disk
# and returns the filename and offsets dictionary
#TODO(corneliu): Add compression support
function persist!(mc::T; filename::String=
                  _generate_cache_filename(mc.name)) where T<:MemoryCache
    # Initialize structures
    _data = mc.cache
    I, O = typeof(_data).parameters # works for `Dict`
    offsets = Dict{I, Tuple{Int,Int}}()
    _dir = join(split(filename, "/")[1:end-1], "/")
    !isempty(_dir) && !isdir(_dir) && mkdir(_dir)
    # Write header
    fid = open(filename, "w")  # overwrite/create file
    serialize(fid, I)
    serialize(fid, O)
    # Write data pairs
    for (hash, datum) in _data
		prevpos = position(fid)
		serialize(fid, datum);
		newpos = position(fid)
        push!(offsets, hash=>(prevpos, newpos))
	end
    close(fid)
    return abspath(filename), offsets
end


# Function that dumps the DiskCache memory component to disk
# and updates the offsets dictionary
function persist!(dc::T; filename::String=dc.filename) where T<:DiskCache
    dc.filename, dc.offsets = persist!(dc.memcache, filename=filename)
    return dc
end


macro persist(symb::Symbol, filename::String...)
    if isempty(filename)
        return esc(:(persist!($symb)))
    else
        return esc(:(persist!($symb, filename=$(filename[1]))))
    end
end


# Erases the memory cache
function empty!(mc::MemoryCache; empty_disk::Bool=false)
    empty!(mc.cache)
    return mc
end


# Erases the memory cache
function empty!(dc::DiskCache; empty_disk::Bool=false)
    empty!(dc.memcache)     # remove memory cache
    if empty_disk           # remove offset structure and the file
        empty!(dc.offsets)
        isfile(dc.filename) && rm(dc.filename, recursive=true, force=true)
    end
    return dc
end


macro empty(symb::Symbol, empty_disk::Bool=false)
    return esc(:(empty!($symb, empty_disk=$empty_disk)))
end
