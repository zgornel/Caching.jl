# Disk caching

mutable struct DiskCache{T<:Function, I<:Unsigned, O} <: AbstractCache
    filename::String                    # file name
    memcache::MemoryCache{T, I, O}      # MemoryCache structure (active)
    offsets::Dict{I, Tuple{Int, Int}}   # existing hash - to - file positions
end


# Function that generates a name based on the name of the cached function
_generate_cache_filename(fname::String) = begin
    _filename = "_" * string(hash(fname), base=16) * "_.bin"
    return abspath(_filename)
end


# Overload constructor
DiskCache(f::T where T<:Function;
		  name::String = string(f),
		  filename::String = _generate_cache_filename(name),
		  input_type::Type=UInt,
		  output_type::Type=Any) = begin
    DiskCache(abspath(filename),
              MemoryCache(name, f, Dict{input_type, output_type}()),
              Dict{input_type, Tuple{Int, Int}}())
end


# Show method
show(io::IO, dc::DiskCache) = begin
    _msz = length(dc.memcache.cache)
    _dsz = length(dc.offsets)
    _tsz = length(symdiff(keys(dc.memcache.cache), keys(dc.offsets))) +
           length(intersect(keys(dc.memcache.cache), keys(dc.offsets)))
    _en = ifelse(_tsz == 1, "entry", "entries")
    println(io, "$(dc.memcache.name) " *
            "(disk cache with $_tsz $_en, $_msz in memory $_dsz on disk)")
end


# Function that retrieves one entry from a stream
function _load_disk_cache_entry(io::T where T<:IO, pos::Int)
    seek(io, pos)
    datum = deserialize(io)
    return datum
end


# Function that stores one entry to a stream
function _store_disk_cache_entry(io::T where T<:IO, pos::Int, datum)
    seek(io, pos)
    serialize(io, datum)
    return position(io)
end


# Call method (caches only to memory, caching to disk has to be explicit)
(dc::DiskCache{T, I, O})(args...; kwargs...) where {T, I, O} = begin
    _hash = arghash(args...; kwargs...)
    if _hash in keys(dc.memcache.cache)
        return dc.memcache.cache[_hash]
    elseif _hash in keys(dc.offsets)
        @warn "Memory hash miss, loading hash=0x$(string(_hash, base=16))..."
        fid = open(dc.filename)
        startpos = dc.offsets[_hash][1]
        datum = _load_disk_cache_entry(fid, startpos)
        close(fid)
        return datum::O
    else
        return dc.memcache(args...; kwargs...)
    end
end


# Macros
# TODO(Corneliu): Support macro arguments i.e. julia> @diskcache @memcache foo
# TODO(Corneliu): Support julia> @diskcache foo(x) = begin ... end and other
#   method and function definition forms
# Macro supporting construnctions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @diskcache foo # now `fooc` is the cached version of `foo`
macro diskcache(symb::Symbol, filename::String=
                _generate_cache_filename(string(symb)))
    _name = String(symb)
    ex = quote
        try
            DiskCache($symb,
                      name=$_name,
                      filename=$filename)
        catch excep
            @error "Could not create DiskCache. $excep"
        end
    end
    return esc(ex)
end  # macro


# Macro supporting constructions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @diskcache foo::Int  # expects output to be `Int`
macro diskcache(expr::Expr, filename::String=
                _generate_cache_filename(string(expr.args[1])))
	@assert expr.head == :(::)
	@assert length(expr.args) == 2  # two arguments
	_symb = expr.args[1]
	_typesymbol = expr.args[2]
	_type = eval(_typesymbol)
	_name = String(_symb)

	try
        @assert _type isa Type
	catch  # it may be a variable containing a type
        @error "The right-hand argument of `::` is not a type."
	end

	ex = quote
        try
            DiskCache($_symb,
                      name=$_name,
                      filename=$filename,
                      output_type=$_type)
        catch excep
            @error "Could not create DiskCache. $excep"
        end
    end
    return esc(ex)
end  # macro
