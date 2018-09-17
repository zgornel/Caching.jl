# Caching.jl

A minimalistic approach to method caching in Julia.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md) 
[![Build Status](https://travis-ci.org/zgornel/Caching.jl.svg?branch=master)](https://travis-ci.org/zgornel/Caching.jl) 
[![Coverage Status](https://coveralls.io/repos/github/zgornel/Caching.jl/badge.svg?branch=master)](https://coveralls.io/github/zgornel/Caching.jl?branch=master)

## Introduction

This package provides a simple programming interface to caching the function output (i.e. memoization) either to memory or to disk. To this purpose it has a simplistic API that exposes functionality for creating cache structures and accessing, writing and synchronizing these to disk. Compression is supported through [TranscodingStreams.jl](https://github.com/bicycle1885/TranscodingStreams.jl) codecs. Since this a work-in-progress, there are bound to be rough edges and little to no documentation. However, the interface is accessible enough to be productively employed at this stage.



## Documentation

The basic structure is the `MemoryCache` object that can be easily constructed employed using the `@memcache` macro.
```julia
foo(x) = x+1  # define function
# foo (generic function with 1 method)

julia> mc = @memcache foo
# foo (memory cache with 0 entries)

julia> mc(1)  # equivalent to foo(1), stores output to cache
# 2

julia> mc.cache
# Dict{UInt64,Any} with 1 entry:
#   0x1c25d5a28cc1adc8 => 2

julia> mc = @memcache foo::Int  # provide return type information
# foo (memory cache with 0 entries)

julia> mc(1)  # add one entry to cache
# 2

julia> mc.cache
# Dict{UInt64,Int64} with 1 entry:
#   0x1c25d5a28cc1adc8 => 2

julia> @code_warntype mc(1)  # check type stability
# Body::Int64
# 20 1 ─ %1 = (getfield)(args, 1)::Int64
# ...
```

The second basic structure is the `DiskCache` which is similar to `MemoryCache` however, it supports reading and writing the cache to disk. It can be created by using the `@diskcache` macro:
```julia
julia> dc = @diskcache foo "somefile.bin"
# foo (disk cache with 0 entries, 0 in memory 0 on disk)

julia> dc(1)  # add one entry to cache
# 2

julia> dc
# foo (disk cache with 1 entry, 1 in memory 0 on disk)

julia> dc.memcache  # the object has a MemoryCache field
# foo (memory cache with 1 entry)

julia> dc.offsets  # disk cache information (hash=>(start byte, end byte))
# Dict{UInt64,Tuple{Int64,Int64}} with 0 entries

julia> dc.filename  # file information
# /absolute/path/to/somefile.bin"

julia> isfile("somefile.bin")  # file does not exist
# false
```

The cache can be written to disk using the `persist!` function or the `@persist!` macro:
```julia
julia> @persist! dc  # writes cache to disk and updates offsets 
# foo (disk cache with 1 entry, 1 in memory 1 on disk)

julia> isfile("somefile.bin")
# true

julia> dc.offsets  # file information
# Dict{UInt64,Tuple{Int64,Int64}} with 1 entry:
#   0x1c25d5a28cc1adc8 => (19, 28)
```

If no file name is provided to the `@persist!` macro or corresponding `persist!` function, a file name will be automatically generated. It is possivle to write the cache for `MemoryCache` objects as well:
```julia
julia> mc
# foo (memory cache with 1 entry)

julia> @persist! mc "someotherfile.bin"  # saves the cache to disk and returns a path and file offsets
# ("/absolute/path/to/someotherfile.bin", Dict(0x1c25d5a28cc1adc8=>(19, 28)))

julia> DiskCache(ans[1], mc, ans[2])  # One can create a DiskCache pointing to the file 
# foo (disk cache with 1 entry, 1 in memory 1 on disk)
```

The cache can be deleted using the `empty!` function or the `@empty!` macro:
```julia
julia> @empty! mc
# foo (memory cache with 0 entries)

julia> @empty! dc  # delete memory cache
# foo (disk cache with 1 entry, 0 in memory 1 on disk)

julia> @empty! dc true  # delete also the disk cache
# foo (disk cache with 0 entries, 0 in memory 0 on disk)

julia> isfile("somefile.bin")
false
```

In case of a `DiskCache` memory hash miss, the cached data is retrieved from disk if available:
```julia
julia> dc = @diskcache foo::Int "somefile.bin"
       for i in 1:3 dc(i); end  # add 3 entries
       @persist! dc
       @assert isfile("somefile.bin")
       @empty! dc  # empty memory cache
       @assert isempty(dc.memcache.cache)
       for i in 4:6 dc(i); end  # add 3 new entries
       dc
# foo (disk cache with 6 entries, 3 in memory 3 on disk)

julia> dc(1)  # only on disk
# ┌ Warning: Memory hash miss, loading hash=0xfd4c549ffbee2b1b...
# └ @ Caching ~/projects/Caching.jl/src/diskcache.jl:65
# 2

julia> dc(4)  # in memory
# 5
```

`DiskCache` objects support also a basic form of synchronization between the memory and disk cache contents. This is done with the help of the `syncache!` function and `@syncache!` macro:
```julia
julia> dc = @diskcache foo "somefile.bin"  # make a DiskCache object
# foo (disk cache with 0 entries, 0 in memory 0 on disk)

julia> for i in 1:5 dc(i); end # populate the memory cache with 5 entries

julia> @persist! dc  # write to disk the cache
# foo (disk cache with 5 entries, 5 in memory 5 on disk)

julia> @empty! dc  # delete the memory cache
# foo (disk cache with 5 entries, 0 in memory 5 on disk)

julia> @syncache! dc "disk"  # load cache from disk
# foo (disk cache with 5 entries, 5 in memory 5 on disk)

julia> @empty! dc  # empty memory cache 
foo (disk cache with 5 entries, 0 in memory 5 on disk)

julia> for i in 1:3  dc(-i); end  # populate the memory cache with 3 new entries

julia> @syncache! dc "memory"  # write memory cache to disk
# foo (disk cache with 8 entries, 3 in memory 8 on disk)

julia> @empty! dc
# foo (disk cache with 8 entries, 0 in memory 8 on disk)

julia> @syncache! dc "disk"  # load cache from disk
# foo (disk cache with 8 entries, 8 in memory 8 on disk)

julia> dc.memcache.cache  # view the cache
# Dict{UInt64,Any} with 8 entries:
#   0xaa9c225ce8a1bd59 => 3
#   ...

julia> dc.offsets  # view the file offsets
# Dict{UInt64,Tuple{Int64,Int64}} with 8 entries:
#   0xaa9c225ce8a1bd59 => (19, 28)
#   ...
```

Synchronization of disk and memory cache contents can also be performed in one go by passing `"both"` in the `@syncache!` macro call:
```julia
julia> dc = @diskcache foo
# foo (disk cache with 0 entries, 0 in memory 0 on disk)

julia> for i in 1:3 dc(i); end  # populate the memory cache with 3 entries

julia> @syncache! dc "memory"  # write to disk
# foo (disk cache with 3 entries, 3 in memory 3 on disk)

julia> @empty! dc  # delete the in-memory cache
# foo (disk cache with 3 entries, 0 in memory 3 on disk)

julia> for i in 1:5 dc(-i); end  # populate the in-memory cache with 5 new entries

julia> @syncache! dc "both"     # sync both memory and disk
# foo (disk cache with 8 entries, 8 in memory 8 on disk)

julia> dc.memcache.cache
# Dict{UInt64,Any} with 8 entries:
#   0xd27248f96ad8691b => -4
#   ...
```
More usage examples can be found in the `test/runtests.jl` file.



## Limitations and Caveats

Some limitations of this package that will have to be taken into consideration are:
- no support for a maximum size of the cache or replacement policy; only a full deletion of the cache is supported
- the cache access is not type-stable unless types are explicitly provided i.e. `@memcache foo::MyType`
- the caching mechanism is unaware of any syste-wide limitations on either memory or disk (TODO)
- multithreading/parallelism is not explicitly supported (TODO)
- the `@memcache` and `@diskcache` do not support entire function definitions i.e. `@memcache foo(x)=x` or `@memcache x->x+1` (TODO)



## Installation

The installation can be done through the usual channels (manually by cloning the repository or installing it though the julia `REPL`).



## License

This code has an MIT license and therefore it is free.



## References

[1] https://en.wikipedia.org/wiki/Memoization

[2] https://en.wikipedia.org/wiki/Cache_replacement_policies

For other caching solutions,  check out also [LRUCache.jl](https://github.com/JuliaCollections/LRUCache.jl), [Memoize.jl](https://github.com/simonster/Memoize.jl) and [Anamnesis.jl](https://github.com/ExpandingMan/Anamnesis.jl)
