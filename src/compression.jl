# Function that retrieves one entry from a stream
function _load_disk_cache_entry(io::IO, pos_start::Int, pos_end::Int;
                                decompressor=Noop)
    seek(io, pos_start)
    cbuf = read(io, pos_end-pos_start)
    buf = transcode(decompressor, cbuf)
    datum = deserialize(IOBuffer(cbuf))
    return datum
end


# Function that stores one entry to a stream
function _store_disk_cache_entry(io::IO, pos::Int, datum;
                                 compressor=Noop)
    seek(io, pos)
    buf = IOBuffer()
    serialize(buf, datum)
    posbuf = position(buf)
    cbuf = transcode(compressor, buf.data[1:posbuf])
    write(io, cbuf)
    return position(io)
end


function _get_transcoders(filename::T="") where T<:AbstractString
    ext = split(filename, ".")[end]
    if ext == "lz4"
        compressor = LZ4Compressor
        decompressor = LZ4Decompressor
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
