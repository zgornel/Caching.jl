##################################################################
# LRUCaching.jl - a memory/disk caching utility           	     #
#                 written in Julia by Cornel Cofaru              #
#                 at 0x0α Research, 2018                         #
##################################################################
module LRUCaching

using Random
import Base.show

abstract type AbstractCache end

export AbstractCache, 
    MemoryCache,
    DiskCache,
    @memcache,
    @diskcache,
    sync!, sync,
    dump

include("memcache.jl")
include("diskcache.jl")
include("utils.jl")

end  # module
