# Caching.jl

Memory and disk memoizer written in Julia.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md) 
[![Build Status](https://travis-ci.org/zgornel/Caching.jl.svg?branch=master)](https://travis-ci.org/zgornel/Caching.jl) 
[![Coverage Status](https://coveralls.io/repos/github/zgornel/Caching.jl/badge.svg?branch=master)](https://coveralls.io/github/zgornel/Caching.jl?branch=master)

## Introduction

This package provides a simple programming interface for caching function outputs (i.e. memoization) to memory, disk or both. The API that exposes functionality for creating in-memory cache structures and accessing, writing and synchronizing these to disk. It supports maxim sizes (in number of objects of KiB of memory) and compression (through [TranscodingStreams.jl](https://github.com/bicycle1885/TranscodingStreams.jl) codecs). Since this a work-in-progress, there are bound to be rough edges and little to no documentation. However, the interface is accessible enough to be productively employed at this stage.



## Main features
- Non intrusive, easy to use `@cache` macro
- Fast and type stable if type annotations are used in the function definitions
- Loading/saving from/to disk with compression (`.bzip2` and `.gzip`)
- Maximum in-memory cache size (either number of objects or bytes)
- Can save almost anything to disk (uses `Serialization` so it is slow)



## Documentation

The caching object is named `Cache` and it can be easily constructed using the `@cache` macro. Most of the examples provided here employ the macros as this is the recommended usage pattern. There are several supported expressions that can be used to construct `Cache`s:
```julia
# Function definitions
julia> using Caching
       @cache function foo(x)  # or `@cache function foo(x)::Type` for type stability
            # ...
       end

# 1-argument anonymous functions
julia> @cache foo2 = x->x+1  # or `@cache foo2 = x::Int->x+1` for type-stability

# Existing functions (Caching.Cache objects returned)
julia> foo3(x) = x;
       foo3_cache = @cache foo3 # or `@cache foo3::Int` for type-stability
```

The `Cache` object itself supports reading/writing cached entries from/to memory and to disk.
```julia
julia> foo(x) = x+1
       dc = @cache foo "somefile.bin"
# foo (cache with 0 entries, 0 in memory 0 on disk)

julia> dc(1)  # add one entry to cache
# 2

julia> dc
# foo (cache with 1 entry, 1 in memory 0 on disk)

julia> dc.cache
# Dict{UInt64,Any} with 1 entry:
#   0x17aa5f390831e792 => 2

julia> dc.offsets  # disk cache information (hash=>(start byte, end byte))
# Dict{UInt64,Tuple{UInt64,UInt64}} with 0 entries

julia> dc.filename  # file information
# /absolute/path/to/somefile.bin"

julia> isfile(dc.filename)  # file does not exist
# false
```

The cache can be written to disk using the `persist!` function or the `@persist!` macro:
```julia
julia> @persist! dc  # writes cache to disk and updates offsets 
# foo (cache with 1 entry, 1 in memory 1 on disk)

julia> isfile(dc.filename)
# true

julia> dc.offsets  # file information
# Dict{UInt64,Tuple{UInt64,UInt64}} with 1 entry:
#   0x17aa5f390831e792 => ...
```

The cache can be deleted using the `empty!` function or the `@empty!` macro:
```julia
julia> @empty! dc  # delete memory cache
# foo (cache with 1 entry, 0 in memory 1 on disk)

julia> @empty! dc true  # delete also the disk cache
# foo (cache with 0 entries, 0 in memory 0 on disk)

julia> isfile("somefile.bin")
false
```

If no file name is provided when creating a `Cache` object, a file name will be automatically generated:
```julia
julia> dc = @cache foo
# foo (cache with 0 entries, 0 in memory 0 on disk)

julia> dc.filename
# "/absolute/path/to/current/directory/_c081687ce69ccdaf_.bin"
```

In case of a `Cache` memory miss, the cached data is retrieved from disk if available:
```julia
julia> dc = @cache foo::Int "somefile.bin"
       for i in 1:3 dc(i); end              # add 3 entries
       @persist! dc
       @assert isfile("somefile.bin")
       @empty! dc                           # empty memory cache
       @assert isempty(dc.cache)
       for i in 4:6 dc(i); end              # add 3 new entries
       dc
# foo (cache with 6 entries, 3 in memory 3 on disk)

julia> dc(1)  # only on disk
# ┌ Warning: Memory cache miss, loading hash=0x17aa5f390831e792...
# └ @ Caching ../Caching.jl/src/cache.jl:53
# 2

julia> dc(4)  # in memory
# 5
```

Synchronization between the memory and disk cache contents is done with the help of the `syncache!` function and `@syncache!` macro:
```julia
julia> dc = @cache foo "somefile.bin"       # make a Cache object
       for i in 1:5 dc(i); end              # populate the memory cache with 5 entries
       @persist! dc                         # write to disk the cache the 5 entries
       @empty! dc                           # delete the memory cache
# foo (cache with 5 entries, 0 in memory 5 on disk)

julia> @syncache! dc "disk"                 # load cache from disk
# foo (cache with 5 entries, 5 in memory 5 on disk)

julia> @empty! dc  # empty memory cache 
       for i in 1:3  dc(-i); end            # populate the memory cache with 3 new entries
       @syncache! dc "memory"               # write memory cache to disk
# foo (cache with 8 entries, 3 in memory 8 on disk)

julia> @empty! dc
       @syncache! dc "disk"                 # load cache from disk
# foo (cache with 8 entries, 8 in memory 8 on disk)

julia> dc.cache  # view the cache
# Dict{UInt64,Any} with 8 entries:
#   0xaa9c225ce8a1bd59 => 3
#   ...

julia> dc.offsets  # view the file offsets
# Dict{UInt64,Tuple{UInt64,UInt64}} with 8 entries:
#   0xaa9c225ce8a1bd59 => ...
#   ...
```

Synchronization of disk and memory cache contents can also be performed in one go by passing `"both"` in the `@syncache!` macro call:
```julia
julia> dc = @cache foo;
       for i in 1:3 dc(i); end              # populate the memory cache with 3 entries
       @syncache! dc "memory"               # write to disk the 3 entries
       @empty! dc                           # delete the in-memory cache
       for i in 1:5 dc(-i); end             # populate the in-memory cache with 5 new entries
       @syncache! dc "both"                 # sync both memory and disk
# foo (cache with 8 entries, 8 in memory 8 on disk)

julia> dc.cache
# Dict{UInt64,Any} with 8 entries:
#   0xd27248f96ad8691b => -4
#   ...
```

`Cache` objects support also a maximum size that specifies the maximum size in either number of entries (i.e. function outputs) or the maximum memory size allowed:
```julia
julia> foo(x) = x
       dc = @cache foo "somefile.bin" 3     # 3 objects max; use Int for objects
       for i in 1:3 dc(i) end               # cache is full
       dc(4)                                # 1 is removed (FIFO rule)
       @assert !(1 in values(dc.cache)) &&
         all(i in values(dc.cache) for i in 2:4)
       @persist! dc
       @empty! dc                           # 2,3,4 on disk
       for i in 5:6 dc(i) end               # 5 and 6 in memory
       @syncache! dc                        # brings 4 (most recent on disk) in memory and writes 5,6 on disk
# ┌ Warning: Memory cache full, loaded 1 out of 3 entries.
# └ @ Caching ~/.../Caching.jl/src/utils.jl:145
# foo (cache with 5 entries, 3 in memory 5 on disk)

julia> dc = @cache foo "somefile.bin" 1.0   # 1.0 --> 1 KiB = 1024 bytes max; use Float64 for KiB
       for i in 1:128 dc(i) end             # cache is full (128 x 8bytes/Int = 1024 bytes)
       dc(129)                              # 1 is removed
       @assert !(1 in values(dc.cache)) &&
         all(i in values(dc.cache) for i in 2:129)
       @persist! dc
       @empty! dc                           # 2,...,129 on disk, nothing in memory
       for i in 130:130+126 dc(i) end       # write 127 entries
       #--> 130,..,256 in memory, 2,...,129 on disk
       @syncache! dc                        # brings 129 in memory and 130,...,256 on disk
# ┌ Warning: Memory cache full, loaded 1 out of 128 entries.
# └ @ Caching ~/.../Caching.jl/src/utils.jl:145
# foo (cache with 255 entries, 128 in memory 255 on disk)
```
More usage examples can be found in the `test/runtests.jl` file.



## Installation

The installation can be done through the usual channels (manually by cloning the repository or installing it though the julia `REPL`).



## License

This code has an MIT license and therefore it is free.



## References

[1] https://en.wikipedia.org/wiki/Memoization

[2] https://en.wikipedia.org/wiki/Cache_replacement_policies

For other caching solutions,  check out also [LRUCache.jl](https://github.com/JuliaCollections/LRUCache.jl), [Memoize.jl](https://github.com/simonster/Memoize.jl) and [Anamnesis.jl](https://github.com/ExpandingMan/Anamnesis.jl)
