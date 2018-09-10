module LRUCaching

import Base.show                                                                                                                                                                                          
abstract type AbstractCache end

export AbstractCache,
	   MemoryCache,
	   DiskCache,
	   @memcache


include("memcache.jl")
include("diskcache.jl")

end  # module
