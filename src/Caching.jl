#################################################################
# Caching.jl - a memory/disk caching utility                    #
#   written in Julia by Cornel Cofaru at 0x0α Research, 2018    #
#################################################################
module Caching

using Random
using Serialization
using TranscodingStreams
using CodecZlib, CodecBzip2, CodecLz4
import Base: show, empty!

abstract type AbstractCache end

export AbstractCache,
    arghash,
    MemoryCache,
    DiskCache,
    syncache!,
    persist!,
    empty!,
    @diskcache,
    @memcache,
    @syncache!,
    @persist!,
    @empty!

    include("memcache.jl")
    include("diskcache.jl")
    include("hash.jl")
    include("utils.jl")
    include("compression.jl")
end  # module
