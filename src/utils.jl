# Hash all input arguments and return a final hash
function arghash(args...; kwargs...)
    _Hash_ = UInt(0)
    for arguments in (args, kwargs)
        _temp_hash_ = UInt(0)
        for _a in arguments
            _temp_hash_ += hash(_a) + hash(typeof(_a))
        end
        _Hash_ += hash(_temp_hash_)
    end
    return hash(_Hash_)
end



# Function that dumps the whole Cache cache to disk overwriting any
# existing cache; returns the cache with a new disk cache information
# i.e. offsets member
function persist!(cache::Cache{T, O, S}, filename::String=cache.filename) where
        {T<:Function, O, S<:AbstractSize}
    # Initialize structures
    empty!(cache.offsets)
    _dir = join(split(filename, "/")[1:end-1], "/")
    !isempty(_dir) && !isdir(_dir) && mkpath(_dir)
    compressor, _ = get_transcoders(filename)
    # Write header
    cache.filename = abspath(filename)
    open(cache.filename, "w") do fid
        serialize(fid, O)
        # Write data pairs (starting with the oldest)
        for _Hash_ in cache.history
            startpos = uposition(fid)
            endpos = store_disk_cache_entry(fid, startpos, cache.cache[_Hash_],
                                            compressor=compressor)
            push!(cache.offsets, _Hash_=>(startpos, endpos))
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
    empty!(cache.history)   # remove the history of the entries
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
function syncache!(cache::Cache{T, O, S}; with::String="both") where {T<:Function, O, S<:AbstractSize}
    # Check keyword argument values, correct unknown values
    DEFAULT_SYNC = "both"
    noff = length(cache.offsets)
    !(with in ("disk", "memory", "both")) && begin
        @warn "Unrecognized value with=$with, defaulting to $DEFAULT_SYNC."
        with = DEFAULT_SYNC
    end
    # Cache synchronization
    if !isfile(cache.filename)
        if with == "both" || with == "memory"
            noff != 0 &&
                @warn "Missing cache file, persisting $(cache.filename)..."
            persist!(cache)
        else
            @warn "Missing cache file, creating $(cache.filename)..."
            empty!(cache)
        end
    else
        cache_ok = check_disk_cache(cache.filename, cache.offsets, O)
        if !cache_ok && with != "disk"
            @warn "Inconsistent cache file, overwriting $(cache.filename)..."
            persist!(cache)
        elseif !cache_ok && with == "disk"
            @warn "Inconsistent cache file, deleting $(cache.filename)..."
            rm(cache.filename, recursive=true, force=true)
        else  # cache_ok
            # At this point, the `offsets` dictionary should reflect
            # the structure of the file pointed at by the `filename` field
            memonly = setdiff(cache.history, keys(cache.offsets))
            diskonly = setdiff(keys(cache.offsets), cache.history)
            mode = ifelse(with == "both" || with == "memory", "a+", "r")
            compressor, decompressor = get_transcoders(cache.filename)
            # Sort the entries to be loaded from disk from the latest
            # (large starting offset) to the oldest (small starting offset)
            diskorder = sort([h=>off for (h, off) in cache.offsets if h in diskonly],
                             by=x->x[2][1], rev=true)
            # Write
            load_cnt = 0
            memory_full = false
            open(cache.filename, mode) do fid
                # Load from disk as many entries as possible (starting with the most
                # recently saved, as long as the maximum size is not reached
                if with != "memory"
                    for (_Hash_, (startpos, endpos)) in diskorder
                        datum = load_disk_cache_entry(fid, startpos, endpos,
                                                      decompressor=decompressor)
                        # Check size and update cache and history, adding
                        # as the oldest entries those on disk
                        if object_size(cache) + object_size(datum, S) <= max_cache_size(cache)
                            push!(cache.cache, _Hash_=>datum)
                            pushfirst!(cache.history, _Hash_)
                            load_cnt += 1
                        else
                            memory_full = true
                            break
                        end
                    end
                    memory_full && @warn "Memory cache full, loaded $load_cnt" *
                                         " out of $(length(diskorder)) entries."
                end
                # Write memory to disk and update offsets;
                # size restrictions do not matter in this case
                if with != "disk"
                    seekend(fid)
                    for _Hash_ in memonly # `memonly` already sorted
                        datum = cache.cache[_Hash_]
                        startpos = uposition(fid)
                        endpos = store_disk_cache_entry(fid, startpos, datum,
                                                        compressor=compressor)
                        push!(cache.offsets, _Hash_=>(startpos, endpos))
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
