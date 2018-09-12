# Additional constructors
DiskCache(mc::MemoryCache{T, I, O};
		  filename::String = _generate_cache_filename(mc.name)) where {T, I, O} =
    DiskCache(filename, deepcopy(mc), Dict{I, Tuple{Int, Int}}())


MemoryCache(dc::DiskCache) = deepcopy(dc.memcache)


# `with` parameter behavior:
#   "both" - memory and disk concents are combined, memory values update disk
#   "disk" - memory cache contents are updated with disk ones
#   "memory" - disk cache contents are updated with memory ones
function syncache!(dc::DiskCache{T, I, O};
                   with::String="both",
                   mode::String="inclusive") where {T, I, O}
    # Check keyword argument values, correct unknown values
    _default_with = "both"
    _default_mode = "inclusive"
    !(with in ["disk", "memory", "both"]) && begin
        @warn "Unrecognized value with=$with, defaulting to $_default_with."
        with = _default_with
    end
    !(mode in ["inclusive", "exclusive"]) && begin
        @warn "Unrecognized value mode=$with, defaulting to $_default_mode."
        with = _default_mode
    end

    # Cache synchronization
    if !isfile(dc.filename)
        if with == "both" || with == "memory"
            noff = length(dc.offsets)
            noff != 0 && @warn "Missing cache file, $noff existing offsets will be deleted."
            persist!(dc)
        else
            empty!(dc)
        end
    else
        cache_ok = _check_disk_cache(dc.filename, dc.offsets, I, O)
        # TODO(Corneliu) Add warnings here
        !cache_ok && with != "disk" && persist!(dc)
        !cache_ok && with == "disk" && empty!(dc, empty_disk=true)
        # At this point, the `offsets` dictionary should reflect
        # the structure of the file pointed at by the `filename` field
        mode = ifelse(with == "both" || with == "memory", "w+", "r")
    end
    return dc
end


macro syncache!(symb::Symbol, with::String="both", mode::String="inclusive")
    return esc(:(syncache!($symb, with=$with, mode=$mode)))
end


# Function that dumps the MemoryCache cache to disk
# and returns the filename and offsets dictionary
# TODO(Corneliu): Add compression support
# TODO(Corneliu): Support for appending to existing data
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


# Erases the memory and possibly the disk cache
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
