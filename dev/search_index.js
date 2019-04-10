var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Introduction",
    "title": "Introduction",
    "category": "page",
    "text": "CurrentModule=Caching"
},

{
    "location": "#Introduction-1",
    "page": "Introduction",
    "title": "Introduction",
    "category": "section",
    "text": "This package provides a simple programming interface for caching function outputs (i.e. memoization) to memory, disk or both. The API that exposes functionality for creating in-memory cache structures and accessing, writing and synchronizing these to disk. It supports maximum sizes (in number of objects or KiB of memory) and compression (through TranscodingStreams.jl codecs). Since this a work-in-progress, there are bound to be rough edges and little to no documentation. However, the interface is accessible enough to be productively employed at this stage."
},

{
    "location": "#Main-features-1",
    "page": "Introduction",
    "title": "Main features",
    "category": "section",
    "text": "Non intrusive, easy to use @cache macro\nFast and type stable if type annotations are used in the function definitions\nLoading/saving from/to disk with compression (.bzip2 and .gzip)\nMaximum in-memory cache size (either number of objects or bytes)\nCan save almost anything to disk (uses Serialization so it is slow)"
},

{
    "location": "#Installation-1",
    "page": "Introduction",
    "title": "Installation",
    "category": "section",
    "text": "In the shell of choice, using$ git clone https://github.com/zgornel/Caching.jlor, inside Julia] add Cachingand for the latest master branch,] add https://github.com/zgornel/Caching.jl#master"
},

{
    "location": "examples/#",
    "page": "Usage examples",
    "title": "Usage examples",
    "category": "page",
    "text": ""
},

{
    "location": "examples/#Usage-examples-1",
    "page": "Usage examples",
    "title": "Usage examples",
    "category": "section",
    "text": "The following examples show how Caching can be employed to cache function outputs. Most examples employ the macros as this is the most straightforward usage pattern."
},

{
    "location": "examples/#The-Cache-object-1",
    "page": "Usage examples",
    "title": "The Cache object",
    "category": "section",
    "text": "The caching object is named Cache and it can be easily constructed using the @cache macro. There are several supported expressions that can be used to construct Caches:using Caching, InteractiveUtils@cache function foo(x)\n    x+1\nend\ntypeof(foo)\n@code_warntype foo(1)or, for type stability,@cache function foo2(x)::Int\n    x+1\nend\n@code_warntype foo2(1)The approach works for anonymous functions as well:@cache foo3 = x->x-1or, for type stability,@cache foo4 = x::Int->x-1\n@code_warntype foo3(1)\n@code_warntype foo4(1)"
},

{
    "location": "examples/#Memory-and-disk-memoization-1",
    "page": "Usage examples",
    "title": "Memory and disk memoization",
    "category": "section",
    "text": "The Cache object itself supports reading/writing cached entries from/to memory and to disk.note: Note\nRe-using the cached function outputs from a file is not possible once the in-memory Cache object goes out of scope.foo5(x) = x+1\ndc = @cache foo5 \"somefile.bin\"\ndc(1);  # add one entry to cache\ndc.cache\ndc.offsets  # disk cache information (hash=>(start byte, end byte))\ndc.filename  # file information\nisfile(dc.filename)  # file does not existThe cache can be written to disk using the persist! function or the @persist! macro:@persist! dc  # writes cache to disk and updates offsets \nisfile(dc.filename)\ndc.offsetsThe cache can be deleted using the empty! function or the @empty! macro:@empty! dc  # delete memory cache\n@empty! dc true  # delete also the disk cache\nisfile(\"somefile.bin\")If no file name is provided when creating a Cache object, a file name will be automatically generated:dc = @cache foo5\ndc.filename"
},

{
    "location": "examples/#Cache-misses-1",
    "page": "Usage examples",
    "title": "Cache misses",
    "category": "section",
    "text": "In case of a cache memory miss, the cached data is retrieved from disk if available:dc = @cache foo5::Int \"somefile.bin\"\nfor i in 1:3 dc(i); end              # add 3 entries\n@persist! dc\n@assert isfile(\"somefile.bin\")\n@empty! dc                           # empty memory cache\n@assert isempty(dc.cache)\nfor i in 4:6 dc(i); end              # add 3 new entries\ndc\ndc(1)  # only on disk\ndc(4)  # in memory"
},

{
    "location": "examples/#Memory-disk-synchronization-1",
    "page": "Usage examples",
    "title": "Memory-disk synchronization",
    "category": "section",
    "text": "Synchronization between the memory and disk cache contents is done with the help of the syncache! function and @syncache! macro:dc = @cache foo5 \"somefile.bin\"       # make a Cache object\nfor i in 1:5 dc(i); end              # populate the memory cache with 5 entries\n@persist! dc                         # write to disk the cache the 5 entries\n@empty! dc                           # delete the memory cache\n\n@syncache! dc \"disk\"                 # load cache from disk\n@empty! dc  # empty memory cache \nfor i in 1:3  dc(-i); end            # populate the memory cache with 3 new entries\n@syncache! dc \"memory\"               # write memory cache to disk\n@empty! dc\n@syncache! dc \"disk\"                 # load cache from disk\n\ndc.cache  # view the cache\ndc.offsets  # view the file offsetsSynchronization of disk and memory cache contents can also be performed in one go by passing \"both\" in the @syncache! macro call:dc = @cache foo5;\nfor i in 1:3 dc(i); end              # populate the memory cache with 3 entries\n@syncache! dc \"memory\"               # write to disk the 3 entries\n@empty! dc                           # delete the in-memory cache\nfor i in 1:5 dc(-i); end             # populate the in-memory cache with 5 new entries\n@syncache! dc \"both\"                 # sync both memory and disk\n\ndc.cache"
},

{
    "location": "examples/#Maximum-sizes-1",
    "page": "Usage examples",
    "title": "Maximum sizes",
    "category": "section",
    "text": "Cache objects support maximum sizes in terms of either number of entries (i.e. function outputs) or the maximum memory size allowed:foo6(x) = x\ndc = @cache foo6 \"somefile.bin\" 3     # 3 objects max; use Int for objects\nfor i in 1:3 dc(i) end               # cache is full\ndc(4)                                # 1 is removed (FIFO rule)\n@assert !(1 in values(dc.cache)) &&\n    all(i in values(dc.cache) for i in 2:4)\n@persist! dc\n@empty! dc                           # 2,3,4 on disk\nfor i in 5:6 dc(i) end               # 5 and 6 in memory\n@syncache! dc                        # brings 4 (most recent on disk) in memory and writes 5,6 on diskdc = @cache foo6 \"somefile.bin\" 1.0   # 1.0 --> 1 KiB = 1024 bytes max; use Float64 for KiB\nfor i in 1:128 dc(i) end             # cache is full (128 x 8bytes/Int = 1024 bytes)\ndc(129)                              # 1 is removed\n@assert !(1 in values(dc.cache)) &&\n    all(i in values(dc.cache) for i in 2:129)\n@persist! dc\n@empty! dc                           # 2,...,129 on disk, nothing in memory\nfor i in 130:130+126 dc(i) end       # write 127 entries\n#--> 130,..,256 in memory, 2,...,129 on disk\n@syncache! dc                        # brings 129 in memory and 130,...,256 on diskMore usage examples can be found in the test/runtests.jl file."
},

{
    "location": "api/#",
    "page": "API Reference",
    "title": "API Reference",
    "category": "page",
    "text": "Modules = [Caching]"
},

]}
