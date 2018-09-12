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
		  input_type::Type=UInt64,
		  output_type::Type=Any) = begin
    DiskCache(abspath(filename),
              MemoryCache(name, f, Dict{input_type, output_type}()),
              Dict{input_type, Tuple{Int, Int}}())
end


# Call method (caches only to memory, caching to disk has to be explicit)
(dc::T where T<:DiskCache)(args...; kwargs...) = dc.memcache(args...; kwargs...)


# Show method
show(io::IO, dc::DiskCache) = begin
	println(io, "Disk cache for \"$(dc.memcache.name)\" " *
            "with $(length(dc.memcache.cache)) entries, $(length(dc.offsets)) on disk.")
end


# Macros
# TODO(Corneliu): Support macro arguments i.e. julia> @diskcache @memcache foo
#
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
