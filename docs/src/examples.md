# Usage examples

The following examples show how `Caching` can be employed to cache function outputs. Most examples employ the macros as this is the most straightforward usage pattern.

## The `Cache` object
The caching object is named `Cache` and it can be easily constructed using the `@cache` macro. There are several supported expressions that can be used to construct `Cache`s:
```@repl index
using Caching, InteractiveUtils
```
```@repl index
@cache function foo(x)
    x+1
end
typeof(foo)
@code_warntype foo(1)
```
or, for type stability,
```@repl index
@cache function foo2(x)::Int
    x+1
end
@code_warntype foo2(1)
```
The approach works for anonymous functions as well:
```@repl index
@cache foo3 = x->x-1
```
or, for type stability,
```@repl index
@cache foo4 = x::Int->x-1
@code_warntype foo3(1)
@code_warntype foo4(1)
```

## Memory and disk memoization

The `Cache` object itself supports reading/writing cached entries from/to memory and to disk.

!!! note

    Re-using the cached function outputs from a file is not possible once the in-memory `Cache` object goes out of scope.

```@repl index
foo5(x) = x+1
dc = @cache foo5 "somefile.bin"
dc(1);  # add one entry to cache
dc.cache
dc.offsets  # disk cache information (hash=>(start byte, end byte))
dc.filename  # file information
isfile(dc.filename)  # file does not exist
```

The cache can be written to disk using the `persist!` function or the `@persist!` macro:
```@repl index
@persist! dc  # writes cache to disk and updates offsets 
isfile(dc.filename)
dc.offsets
```

The cache can be deleted using the `empty!` function or the `@empty!` macro:
```@repl index
@empty! dc  # delete memory cache
@empty! dc true  # delete also the disk cache
isfile("somefile.bin")
```

If no file name is provided when creating a `Cache` object, a file name will be automatically generated:
```@repl index
dc = @cache foo5
dc.filename
```

## Cache misses

In case of a cache memory miss, the cached data is retrieved from disk if available:
```@repl index
dc = @cache foo5::Int "somefile.bin"
for i in 1:3 dc(i); end              # add 3 entries
@persist! dc
@assert isfile("somefile.bin")
@empty! dc                           # empty memory cache
@assert isempty(dc.cache)
for i in 4:6 dc(i); end              # add 3 new entries
dc
dc(1)  # only on disk
dc(4)  # in memory
```

## Memory-disk synchronization

Synchronization between the memory and disk cache contents is done with the help of the `syncache!` function and `@syncache!` macro:
```@repl index
dc = @cache foo5 "somefile.bin"       # make a Cache object
for i in 1:5 dc(i); end              # populate the memory cache with 5 entries
@persist! dc                         # write to disk the cache the 5 entries
@empty! dc                           # delete the memory cache

@syncache! dc "disk"                 # load cache from disk
@empty! dc  # empty memory cache 
for i in 1:3  dc(-i); end            # populate the memory cache with 3 new entries
@syncache! dc "memory"               # write memory cache to disk
@empty! dc
@syncache! dc "disk"                 # load cache from disk

dc.cache  # view the cache
dc.offsets  # view the file offsets
```

Synchronization of disk and memory cache contents can also be performed in one go by passing `"both"` in the `@syncache!` macro call:
```@repl index
dc = @cache foo5;
for i in 1:3 dc(i); end              # populate the memory cache with 3 entries
@syncache! dc "memory"               # write to disk the 3 entries
@empty! dc                           # delete the in-memory cache
for i in 1:5 dc(-i); end             # populate the in-memory cache with 5 new entries
@syncache! dc "both"                 # sync both memory and disk

dc.cache
```

# Maximum sizes

`Cache` objects support maximum sizes in terms of either number of entries (i.e. function outputs) or the maximum memory size allowed:
```@repl index
foo6(x) = x
dc = @cache foo6 "somefile.bin" 3     # 3 objects max; use Int for objects
for i in 1:3 dc(i) end               # cache is full
dc(4)                                # 1 is removed (FIFO rule)
@assert !(1 in values(dc.cache)) &&
    all(i in values(dc.cache) for i in 2:4)
@persist! dc
@empty! dc                           # 2,3,4 on disk
for i in 5:6 dc(i) end               # 5 and 6 in memory
@syncache! dc                        # brings 4 (most recent on disk) in memory and writes 5,6 on disk
```

```@repl index
dc = @cache foo6 "somefile.bin" 1.0   # 1.0 --> 1 KiB = 1024 bytes max; use Float64 for KiB
for i in 1:128 dc(i) end             # cache is full (128 x 8bytes/Int = 1024 bytes)
dc(129)                              # 1 is removed
@assert !(1 in values(dc.cache)) &&
    all(i in values(dc.cache) for i in 2:129)
@persist! dc
@empty! dc                           # 2,...,129 on disk, nothing in memory
for i in 130:130+126 dc(i) end       # write 127 entries
#--> 130,..,256 in memory, 2,...,129 on disk
@syncache! dc                        # brings 129 in memory and 130,...,256 on disk
```

More usage examples can be found in the [test/runtests.jl](https://github.com/zgornel/Caching.jl/blob/master/test/runtests.jl) file.
