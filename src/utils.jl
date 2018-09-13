# Convert MemoryCache to DiskCache (constructor)
DiskCache(mc::MemoryCache{T, I, O};
		  filename::String = _generate_cache_filename(mc.name)) where {T, I, O} =
    DiskCache(filename, deepcopy(mc), Dict{I, Tuple{Int, Int}}())


# Convert DiskCache to MemoryCache (constructor)
MemoryCache(dc::DiskCache) = deepcopy(dc.memcache)


# Function that checks the consistency of the disk cache and `offset`
# field value of the DiskCache object
function _check_disk_cache(filename::String, offsets::D where D<:Dict,
                           input_type::Type, output_type::Type)::Bool
    fid = open(filename, "r")
    try
        I = deserialize(fid)
        @assert I == input_type
        O = deserialize(fid)
        @assert O == output_type
        for (_, (startpos, endpos)) in offsets
            _load_disk_cache_entry(fid, startpos)
        end
        return true
    catch excep
        close(fid)
        return false
    end
end


# Function that dumps the MemoryCache cache to disk
# and returns the filename and offsets dictionary
# TODO(Corneliu): Add compression support
function persist!(mc::MemoryCache{T, I, O}; filename::String=
                  _generate_cache_filename(mc.name)) where {T, I, O}
    # Initialize structures
    _data = mc.cache
    offsets = Dict{I, Tuple{Int, Int}}()
    _dir = join(split(filename, "/")[1:end-1], "/")
    !isempty(_dir) && !isdir(_dir) && mkdir(_dir)
    # Write header
    fid = open(filename, "w")  # overwrite/create file
    serialize(fid, I)
    serialize(fid, O)
    # Write data pairs
    for (_hash, datum) in _data
        startpos = position(fid)
        endpos = _store_disk_cache_entry(fid, startpos, datum)
        push!(offsets, _hash=>(startpos, endpos))
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


macro persist!(symb::Symbol, filename::String...)
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


# Erases the memory and possibly the disk cache
function empty!(dc::DiskCache; empty_disk::Bool=false)
    empty!(dc.memcache)     # remove memory cache
    if empty_disk           # remove offset structure and the file
        empty!(dc.offsets)
        isfile(dc.filename) && rm(dc.filename, recursive=true, force=true)
    end
    return dc
end


macro empty!(symb::Symbol, empty_disk::Bool=false)
    return esc(:(empty!($symb, empty_disk=$empty_disk)))
end


# `with` parameter behavior:
#   "both" - memory and disk concents are combined, memory values update disk
#   "disk" - memory cache contents are updated with disk ones
#   "memory" - disk cache contents are updated with memory ones
function syncache!(dc::DiskCache{T, I, O};
                   with::String="both") where {T, I, O}
    # Check keyword argument values, correct unknown values
    _default_with = "both"
    noff = length(dc.offsets)
    !(with in ["disk", "memory", "both"]) && begin
        @warn "Unrecognized value with=$with, defaulting to $_default_with."
        with = _default_with
    end

    # Cache synchronization
    if !isfile(dc.filename)
        if with == "both" || with == "memory"
            noff != 0 && @warn "Missing cache file, will write memory cache to disk."
            persist!(dc)
        else
            @warn "Missing cache file, will delete all cache."
            empty!(dc)
        end
    else
        cache_ok = _check_disk_cache(dc.filename, dc.offsets, I, O)
        if !cache_ok && with != "disk"
            @warn "Inconsistent cache, overwriting disk contents."
            persist!(dc)
        elseif !cache_ok && with == "disk"
            @warn "Inconsistent cache, will delete all cache."
            empty!(dc, empty_disk=true)
        else  # cache_ok
            # At this point, the `offsets` dictionary should reflect
            # the structure of the file pointed at by the `filename` field
            mode = ifelse(with == "both" || with == "memory", "a+", "r")
            memonly = setdiff(keys(dc.memcache.cache), keys(dc.offsets))
            diskonly = setdiff(keys(dc.offsets), keys(dc.memcache.cache))
            fid = open(dc.filename, mode)
            # Load from disk to memory
            if with != "memory"
                for _hash in diskonly
                    startpos = dc.offsets[_hash][1]
                    datum = _load_disk_cache_entry(fid, startpos)
                    push!(dc.memcache.cache, _hash=>datum)
                end
            end
            # Write memory to disk and update offsets
            if with != "disk"
                for _hash in memonly
                    datum = dc.memcache.cache[_hash]
                    startpos = position(fid)
                    endpos = _store_disk_cache_entry(fid, startpos, datum)
                    push!(dc.offsets, _hash=>(startpos, endpos))
                end
            end
            close(fid)
        end
    end
    return dc
end


macro syncache!(symb::Symbol, with::String="both")
    return esc(:(syncache!($symb, with=$with)))
end
