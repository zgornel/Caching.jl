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
function load_disk_cache_entry(io::IO, pos_start::UInt, pos_end::UInt,
                               decompressor=Noop)
    seek(io, pos_start)
    cbuf = read(io, pos_end-pos_start)
    buf = transcode(decompressor, cbuf)
    datum = deserialize(IOBuffer(buf))
    return datum
end


# Function that stores one entry to a stream
function store_disk_cache_entry(io::IO, pos_start::UInt, datum,
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
                          offsets::D where D<:Dict,
                          output_type::Type)::Bool
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



function get_transcoders(filename::T="") where T<:AbstractString
    ext = split(filename, ".")[end]
    if ext == "bz2" || ext == "bzip2"
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
