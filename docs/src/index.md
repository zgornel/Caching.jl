```@meta
CurrentModule=Caching
```

# Introduction

This package provides a simple programming interface for caching function outputs (i.e. memoization) to memory, disk or both. The API that exposes functionality for creating in-memory cache structures and accessing, writing and synchronizing these to disk. It supports maximum sizes (in number of objects or KiB of memory) and compression (through [TranscodingStreams.jl](https://github.com/bicycle1885/TranscodingStreams.jl) codecs). Since this a work-in-progress, there are bound to be rough edges and little to no documentation. However, the interface is accessible enough to be productively employed at this stage.

## Main features
- Non intrusive, easy to use `@cache` macro
- Fast and type stable if type annotations are used in the function definitions
- Loading/saving from/to disk with compression (`.bzip2` and `.gzip`)
- Maximum in-memory cache size (either number of objects or bytes)
- Can save almost anything to disk (uses `Serialization` so it is slow)

## Installation

In the shell of choice, using
```
$ git clone https://github.com/zgornel/Caching.jl
```
or, inside Julia
```
] add Caching
```
and for the latest `master` branch,
```
] add https://github.com/zgornel/Caching.jl#master
```
