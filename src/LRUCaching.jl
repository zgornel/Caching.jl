module LRUCaching

import Base.show                                                                                                                                                                                          
export Cache

# Object
struct Cache{T<:Function, I, O}
	func::T
	cache::Dict{I, O}
end


# Overload constructor
Cache(f::T where T<:Function) = Cache(f, Dict())


# Call method
(cached_func::T where T<:Cache)(args...) = begin
	hv = hash(map(hash, args))
	out = get(cached_func.cache, hv, nothing)
    if out == nothing
		@info "Hash miss, caching hash=$hv..."
    	out = cached_func.func(args...)
        cached_func.cache[hv] = out
    end
    return out
end


# Show method
show(io::IO, c::Cache) = begin
	print(io, "Cached function $(c.func) with $(length(c.cache)) entries.")
end 

                                                                                
#=
	Make macro that would work like:
	   @memcache - memory cache
	   @diskcache("path/to/file") - disk cache
	
	Example:
	julia> @cache foo  # foo is an existing function OR
	julia> @cache function etc() ... end
	julia> foo(1) # <-- execute function
	julia> foo(1) # <-- load cache
	=#

end # module
