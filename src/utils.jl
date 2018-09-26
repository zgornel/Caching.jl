# Function that checks the consistency of the cache and `offset`
# field value of the Cache object
function _check_disk_cache(filename::String, offsets::D where D<:Dict,
                           input_type::Type, output_type::Type)::Bool
    open(filename, "r") do fid
        _, decompressor = get_transcoders(filename)
        try
            I = deserialize(fid)
            @assert I == input_type
            O = deserialize(fid)
            @assert O == output_type
            for (_, (startpos, endpos)) in offsets
                load_disk_cache_entry(fid, startpos, endpos,
                                      decompressor=decompressor)
            end
            return true
        catch excep
            return false
        end
    end
end



# Function that dumps the whole Cache cache to disk
# and returns the filename and offsets dictionary
function persist!(cache::Cache{T, I, O}, filename::String=cache.filename) where {T, I, O}
    # Initialize structures
    _data = cache.cache
    cache.offsets = Dict{I, Tuple{Int, Int}}()
    _dir = join(split(filename, "/")[1:end-1], "/")
    !isempty(_dir) && !isdir(_dir) && mkpath(_dir)
    compressor, _ = get_transcoders(filename)
    # Write header
    cache.filename = abspath(filename)
    open(cache.filename, "w") do fid
        serialize(fid, I)
        serialize(fid, O)
        # Write data pairs
        for (_hash, datum) in _data
            startpos = position(fid)
            endpos = store_disk_cache_entry(fid, startpos, datum,
                                            compressor=compressor)
            push!(cache.offsets, _hash=>(startpos, endpos))
        end
    end
    return cache
end



macro persist!(symb::Symbol, filename::String...)
    if isempty(filename)
        return esc(:(persist!($symb)))
    else
        return esc(:(persist!($symb, $(filename[1]))))
    end
end



# Erases the memory and possibly the disk cache
function empty!(cache::Cache; empty_disk::Bool=false)
    empty!(cache.cache)     # remove memory cache
    if empty_disk           # remove offset structure and the file
        empty!(cache.offsets)
        isfile(cache.filename) && rm(cache.filename, recursive=true, force=true)
    end
    return cache
end



macro empty!(symb::Symbol, empty_disk::Bool=false)
    return esc(:(empty!($symb, empty_disk=$empty_disk)))
end


# `with` parameter behavior:
#   "both" - memory and disk concents are combined, memory values update disk
#   "disk" - memory cache contents are updated with disk ones
#   "memory" - disk cache contents are updated with memory ones
function syncache!(cache::Cache{T, I, O};
                   with::String="both") where {T, I, O}
    # Check keyword argument values, correct unknown values
    _default_with = "both"
    noff = length(cache.offsets)
    !(with in ["disk", "memory", "both"]) && begin
        @warn "Unrecognized value with=$with, defaulting to $_default_with."
        with = _default_with
    end

    # Cache synchronization
    if !isfile(cache.filename)
        if with == "both" || with == "memory"
            noff != 0 && @warn "Missing cache file, will write memory cache to disk."
            persist!(cache)
        else
            @warn "Missing cache file, will delete all cache."
            empty!(cache)
        end
    else
        cache_ok = _check_disk_cache(cache.filename, cache.offsets, I, O)
        if !cache_ok && with != "disk"
            @warn "Inconsistent cache, overwriting disk contents."
            persist!(cache)
        elseif !cache_ok && with == "disk"
            @warn "Inconsistent cache, will delete all cache."
            empty!(cache, empty_disk=true)
        else  # cache_ok
            # At this point, the `offsets` dictionary should reflect
            # the structure of the file pointed at by the `filename` field
            memonly = setdiff(keys(cache.cache), keys(cache.offsets))
            diskonly = setdiff(keys(cache.offsets), keys(cache.cache))
            mode = ifelse(with == "both" || with == "memory", "a+", "r")
            compressor, decompressor = get_transcoders(cache.filename)
            open(cache.filename, mode) do fid
                # Load from disk to memory
                if with != "memory"
                    for _hash in diskonly
                        startpos = cache.offsets[_hash][1]
                        endpos = cache.offsets[_hash][2]
                        datum = load_disk_cache_entry(fid, startpos, endpos,
                                                      decompressor=decompressor)
                        push!(cache.cache, _hash=>datum)
                    end
                end
                # Write memory to disk and update offsets
                if with != "disk"
                    for _hash in memonly
                        datum = cache.cache[_hash]
                        startpos = position(fid)
                        endpos = store_disk_cache_entry(fid, startpos, datum,
                                                        compressor=compressor)
                        push!(cache.offsets, _hash=>(startpos, endpos))
                    end
                end
            end
        end
    end
    return cache
end



macro syncache!(symb::Symbol, with::String="both")
    return esc(:(syncache!($symb, with=$with)))
end
