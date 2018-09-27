#################################################################
# Caching.jl - a memory/disk caching utility                    #
#   written in Julia by Cornel Cofaru at 0x0α Research, 2018    #
#################################################################
module Caching

using Random
using Serialization
using TranscodingStreams
using CodecZlib, CodecBzip2
using DataStructures
using Base: summarysize

import Base: show, empty!, length
import Core.Compiler: return_type

const MAX_CACHE_SIZE = typemax(Int)

export AbstractCache,
       Cache,
       AbstractSize,
       CountSize,
       MemorySize,
       object_size,
       max_cache_size,
       arghash,
       syncache!,
       persist!,
       empty!,
       @cache,
       @syncache!,
       @persist!,
       @empty!

include("cache.jl")
include("hash.jl")
include("utils.jl")
include("compression.jl")

end  # module
