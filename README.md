# LRUCaching

A minimalistic approach to LRU caching in Julia.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md) 
[![Build Status](https://travis-ci.org/zgornel/LRUCaching.jl.svg?branch=master)](https://travis-ci.org/zgornel/LRUCaching.jl) 
[![Coverage Status](https://coveralls.io/repos/github/zgornel/LRUCaching.jl/badge.svg?branch=master)](https://coveralls.io/github/zgornel/LRUCaching.jl?branch=master)

## Introduction

*LRUCaching.jl* provides a simple programming interface to caching the function output (i.e. memoization) either to memory or to disk. To this purpose it has a simplistic API that exposes functionality for creating cache structures and writing/loading/synchronizing these to disk. Since this a work-in-progress, there are bound to be rough edges and little to no documentation. However, the interface is accessible enough to be productively employed at this stage.



## Documentation

The basic structure is the `MemoryCache` object that can be easily constructed employed using the `@memcache` macro.
```julia
foo(x) = x+1  # define function
# foo (generic function with 1 method)

julia> mc = @memcache foo
# Memory cache for "foo" with 0 entries.

julia> mc(1)  # equivalent to foo(1), stores output to cache
# 2

julia> mc.cache
# Dict{UInt64,Any} with 1 entry:
#   0x7af5cd6266432e85 => 2

julia> mc = @memcache foo::Int  # provide return type information
# Memory cache for "foo" with 0 entries.

julia> mc(1)  # add one entry to cache
# 2

julia> mc.cache
# Dict{UInt64,Int64} with 1 entry:
#   0x7af5cd6266432e85 => 2

julia> @code_warntype mc(1)  # check type stability
# Body::Int64
# 20 1 ─ %1 = (getfield)(args, 1)::Int64                                                                                                                                                               │
# ...
```

The second basic structure is the `DiskCache` which is similar to `MemoryCache` however, it supports reading and writing the cache to disk. It can be created by using the `@diskcache` macro:
```julia
julia> dc = @diskcache foo "somefile.bin"
# Disk cache for "foo" with 0 entries, 0 on disk.

julia> dc(1)  # add one entry to cache
# 2

julia> dc
# Disk cache for "foo" with 1 entries, 0 on disk.

julia> dc.memcache  # the object has a MemoryCache field
# Memory cache for "foo" with 1 entries.

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
# Disk cache for "foo" with 1 entries, 1 on disk.

julia> isfile("somefile.bin")
# true

julia> dc.offsets  # file information
# Dict{UInt64,Tuple{Int64,Int64}} with 1 entry:
#   0x7af5cd6266432e85 => (19, 28)
```
If no file name is provided to the `@persist!` macro or corresponding `persist!` function, a file name will be automatically generated. It is possivle to write the cache for `MemoryCache` objects as well:
```julia
julia> mc
# Memory cache for "foo" with 1 entries.

julia> @persist! mc "someotherfile.bin"  # saves the cache to disk and returns a path and file offsets
# ("/absolute/path/to/someotherfile.bin", Dict(0x7af5cd6266432e85=>(20, 29)))

julia> DiskCache(ans[1], mc, ans[2])  # One can create a DiskCache pointing to the file 
# Disk cache for "foo" with 1 entries, 1 on disk.
```

The cache can be deleted using the `empty!` function or the `@empty!` macro:
```julia
julia> @empty! mc
# Memory cache for "foo" with 0 entries.

julia> @empty! dc  # delete memory cache
Disk cache for "foo" with 0 entries, 1 on disk.

julia> @empty! dc true  # delete also the disk cache
Disk cache for "foo" with 0 entries, 0 on disk.

julia> isfile("somefile.bin")
false
```

`DiskCache` objects support also a basic form of synchronization between the memory and disk cache contents. This is done with the help of the `syncache!` function and `@syncache!` macro:
```julia
julia> dc = @diskcache foo "somefile.bin"  # make a DiskCache object
# Disk cache for "foo" with 0 entries, 0 on disk.

julia> for i in 1:5 dc(i); end # populate the memory cache with 5 entries

julia> @persist! dc  # write to disk the cache
# Disk cache for "foo" with 5 entries, 5 on disk.

julia> @empty! dc  # delete the memory cache
# Disk cache for "foo" with 0 entries, 5 on disk.

julia> @syncache! dc "disk"  # load cache from disk
# Disk cache for "foo" with 5 entries, 5 on disk.

julia> @empty! dc  # empty memory cache 
# Disk cache for "foo" with 0 entries, 5 on disk.

julia> for i in 1:3  dc(-i); end  # populate the memory cache with 3 new entries

julia> @syncache! dc "memory"  # write memory cache to disk
# Disk cache for "foo" with 3 entries, 8 on disk.

julia> @empty! dc
# Disk cache for "foo" with 0 entries, 8 on disk.

julia> @syncache! dc "disk"  # load cache from disk
# Disk cache for "foo" with 8 entries, 8 on disk.

julia> dc.memcache.cache  # view the cache
# Dict{UInt64,Any} with 8 entries:
#   0x399353ebc808c7be => 4
#   0x15ba61458034d7ce => -2
#   0x4fc024de92af514e => 0
#   0x811532f401ee8fbd => 3
#   0x7af5cd6266432e85 => 2
#   0x8d82f7be5ba4c1c1 => 5
#   0x021625ffc652bf9f => 6
#   0xdc41d32ffcb11aac => -1

julia> dc.offsetsa  # view the file offsets
# Dict{UInt64,Tuple{Int64,Int64}} with 8 entries:
#   0x399353ebc808c7be => (19, 28)
#   0x15ba61458034d7ce => (64, 77)
#   0x4fc024de92af514e => (77, 86)
#   0x811532f401ee8fbd => (28, 37)
#   0x7af5cd6266432e85 => (37, 46)
#   0x8d82f7be5ba4c1c1 => (46, 55)
#   0x021625ffc652bf9f => (55, 64)                                                                                                                                                                        
#   0xdc41d32ffcb11aac => (86, 99)                                                                                                                                                                        
```

Synchronization of disk and memory cache contents can also be performed in one go by passing `"both"` in the `@syncache!` macro call:
```julia
julia> fc = @diskcache foo
# Disk cache for "foo" with 0 entries, 0 on disk.

julia> for i in 1:5 fc(i); end  # populate the memory cache with 5 entries

julia> @syncache! fc "memory"  # write to disk
# Disk cache for "foo" with 5 entries, 5 on disk.

julia> @empty! fc  # delete the in-memory cache
# Disk cache for "foo" with 0 entries, 5 on disk.

julia> [fc(-i) for i in 1:5];  # populate the in-memory cache with 5 new entries

julia> @syncache! fc "both"     # sync both memory and disk
# Disk cache for "foo" with 10 entries, 10 on disk.

julia> fc.memcache.cache                                                                                                                                                                                
# Dict{UInt64,Any} with 10 entries:                                                                                                                                                                       
#   0x399353ebc808c7be => 4
#   0x15ba61458034d7ce => -2
#   0x4fc024de92af514e => 0
#   0xf17c264c79ed705a => -4
#   0xb359a1cadf3a6281 => -3
#   0x811532f401ee8fbd => 3
#   0x7af5cd6266432e85 => 2
#   0xdc41d32ffcb11aac => -1
#   0x8d82f7be5ba4c1c1 => 5
#   0x021625ffc652bf9f => 6
```
More usage examples can be found in the `test/runtests.jl` file.



## Limitations and Caveats

Some limitations of this package that will have to be taken into consideration are:
- no support for a maximum size of the cache or replacement policy; only a full deletion of the cache is supported
- no support for Julia v0.6 and lower
- the cache access is not type-stable unless types are explicitly provided i.e. `@memcache foo::MyType`
- the caching mechanism is unaware of any syste-wide limitations on either memory or disk (TODO)
- multithreading/parallelism is not explicitly supported (TODO)
- compression is not supported (TODO)
- the `@memcache` and `@diskcache` do not support entire function definitions i.e. `@memcache foo(x)=x` or `@memcache x->x+1` (TODO)



## Installation

The installation can be done through the usual channels (manually by cloning the repository or installing it though the julia `REPL`).



## License

This code has an MIT license and therefore it is free.



## References

[1] (https://en.wikipedia.org/wiki/Memoization)

[2] (https://en.wikipedia.org/wiki/Cache_replacement_policies)

For another take on LRU caching, check out also [LRUCache.jl](https://github.com/JuliaCollections/LRUCache.jl) and [Memoize.jl](https://github.com/simonster/Memoize.jl)
