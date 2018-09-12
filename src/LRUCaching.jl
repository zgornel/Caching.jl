##################################################################
# LRUCaching.jl - a memory/disk caching utility           	     #
#                 written in Julia by Cornel Cofaru              #
#                 at 0x0α Research, 2018                         #
##################################################################
module LRUCaching

using Random
using Serialization
import Base: show, empty!

abstract type AbstractCache end

export AbstractCache,
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
include("utils.jl")

end  # module
