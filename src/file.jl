# Get an unsigned position
function uposition(stream)
    UInt(position(stream))
end


# Function that generates a name based on the name of the cached function
function generate_cache_filename()
    _filename = "_" * string(hash(rand()), base=16) * "_.bin"
    return abspath(_filename)
end


# Function that retrieves one entry from a stream
function load_disk_cache_entry(io::IO,
                               pos_start::UInt,
                               pos_end::UInt,
                               decompressor=Noop)
    seek(io, pos_start)
    cbuf = read(io, pos_end-pos_start)
    buf = transcode(decompressor, cbuf)
    datum = deserialize(IOBuffer(buf))
    return datum
end


# Function that stores one entry to a stream
function store_disk_cache_entry(io::IO,
                                pos_start::UInt,
                                datum,
                                compressor=Noop)
    seek(io, pos_start)
    buf = IOBuffer()
    serialize(buf, datum)
    posbuf = uposition(buf)
    cbuf = transcode(compressor, buf.data[1:posbuf])
    write(io, cbuf)
    return uposition(io)
end


# Function that checks the consistency of the cache and `offset`
# field value of the Cache object
function check_disk_cache(filename::String,
                          offsets::Dict,
                          output_type::Type
                         )::Bool
    open(filename, "r") do fid
        _, decompressor = get_transcoders(filename)
        try
            O = deserialize(fid);
            @assert O == output_type
            for (_, (startpos, endpos)) in offsets
                load_disk_cache_entry(fid, startpos, endpos, decompressor)
            end
            return true
        catch excep
            return false
        end
    end
end


function get_transcoders(filename::T="") where {T<:AbstractString}
    ext = split(filename, ".")[end]
    if ext == "lz4"
        compressor = LZ4FrameCompressor
        decompressor = LZ4FrameDecompressor
    elseif ext == "bz2" || ext == "bzip2"
        compressor = Bzip2Compressor
        decompressor = Bzip2Decompressor
    elseif ext == "gz" || ext == "gzip"
        compressor = GzipCompressor
        decompressor = GzipDecompressor
    else
        compressor = Noop  # no compression
        decompressor = Noop  # no compression
    end
    return compressor, decompressor
end


cache2nt(cache::Cache) = (name=cache.name,
                          filename=cache.filename,
                          func_def=cache.func_def,
                          cache=cache.cache,
                          offsets=cache.offsets,
                          history=cache.history,
                          max_size=cache.max_size)


serialize(stream::IO, cache::Cache) = serialize(stream, cache2nt(cache))

serialize(filename::AbstractString, cache::Cache) = serialize(filename, cache2nt(cache))


function deserialize(stream_or_filename, ::Type{Cache}; func=nothing)
    nt = deserialize(stream_or_filename)
    if nt.func_def === nothing && func === nothing
        throw(ErrorException("Cannot reconstruct cache; use the `func` keyword argument."))
    elseif func === nothing
        func = try
                eval(Meta.parse(nt.func_def))
            catch e
                throw(ErrorException("Cannot reconstruct cache:\n$e"))
            end
    else
        # use keyword func over serialized function definition code
    end
    return Cache(func, nt...)
end
