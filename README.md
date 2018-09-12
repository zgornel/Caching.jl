# LRUCaching

A minimalistic approach to LRU caching in Julia.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md) 
[![Build Status](https://travis-ci.org/zgornel/LRUCaching.jl.svg?branch=master)](https://travis-ci.org/zgornel/LRUCaching.jl) 
[![Coverage Status](https://coveralls.io/repos/github/zgornel/LRUCaching.jl/badge.svg?branch=master)](https://coveralls.io/github/zgornel/LRUCaching.jl?branch=master)

## Introduction

*LRUCaching.jl* aims at providing a simple programming interface to caching the output of calculations (i.e. memoization) either to memory or to disk. To this purpose it has a simplistic API that exposes functionality for creating cache structures and writing/loading/synchonizing these to disk. Since this a work-in-progress, there are bound to be rough edges and little to no documentation. However, the interface is accessible enough to be productively employed at this stage.



## Documentation

TODO


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
