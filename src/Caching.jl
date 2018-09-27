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

import Base: show, empty!, length
import Core.Compiler: return_type

abstract type AbstractCache end

export AbstractCache,
       Cache,
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
