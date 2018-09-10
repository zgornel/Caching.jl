# Disk caching

struct DiskCache{T<:Function, I<:Unsigned, O} <: AbstractCache
	filename::String
	memcache::MemoryCache{T, I, O}
end


# Function that generates a name based on the name of the cached function
_generate_cache_filename(fname::String) = begin
		return "_" * fname * "_cache_" * string(hash(fname), base=16) * "_"
end


# Overload constructor
DiskCache(f::T where T<:Function;
		  name::String = string(f),
		  filename::String = _generate_cache_filename(name),
		  input_type::Type=UInt64,
		  output_type::Type=Any) =
	DiskCache(filename,
			  MemoryCache(name, f, Dict{input_type, output_type}()))


# Call method
(dc::T where T<:DiskCache)(args...; kwargs...) = begin
	_hash = hash([map(hash, args)..., map(hash, collect(kwargs))...])
	if _hash in keys(dc.memcache.cache)
		out = dc.memcache.cache[_hash]
	else
		@info "Hash miss, caching hash=$_hash..."
		out = dc.memcache.func(args...; kwargs...)
        dc.memcache.cache[_hash] = out
    end
    return out
end


# Show method
# TODO(Corneliu): Show discrepancies between disk and memory states
show(io::IO, c::DiskCache) = begin
	println(io, "Disk cache for \"$(c.memcache.name)\" " *
			"with $(length(c.memcache.cache)) entries.")
end


# Macros

# Macro supporting construnctions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @diskcache foo # now `fooc` is the cached version of `foo`
macro diskcache(symb::Symbol,
				filename::String=_generate_cache_filename(string(symb)))
	@assert isdefined(Main, symb)
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
macro diskcache(expr::Expr,
				filename::String=_generate_cache_filename(string(expr.args[1])))
	@assert expr.head == :(::)
	@assert length(expr.args) == 2  # two arguments
	_symb = expr.args[1]
	_typesymbol = expr.args[2]
	_type = eval(_typesymbol)
	_name = String(_symb)

	@assert isdefined(Main, _symb)  # check that symbol exists
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
