# Disk caching

struct DiskCache{T<:Function, I<:Tuple, O<:AbstractString} <: AbstractCache
	func::T
	cache::Dict{I, O}
	cachefile::String
end


# Overload constructor
# TODO (Corneliu): Add DiskCache constructors
DiskCache(f::T where T<:Function,
		  T1::Type=Tuple,
		  T2::Type=AbstractString) = DiskCache(f, Dict{T1, T2}())


# Call method
(dc::T where T<:DiskCache)(args...; kwargs...) = begin
	#=
	_hashes = (map(hash, args)..., map(hash, collect(kwargs))...)
	if _hashes in keys(mc.cache)
		out = mc.cache[_hashes]
	else
		@info "Hash miss, caching hash=$_hashes..."
		out = mc.func(args...; kwargs...)
        mc.cache[_hashes] = out
    end
    return out
	=#
end


# Show method
show(io::IO, c::DiskCache) = begin
	println(io, "Disk cache for \"$(c.func)\"")
	print(io, "`- [$(c.file)]: $(length(c.cache)) entries.")
end


# Macros

# Simple macro of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @cache foo # now `fooc` is the cached version of `foo`
macro diskcache(ex::Symbol)
	return esc(:(MemoryCache($ex)))
end  # macro
