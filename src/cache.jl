# Cache struct
mutable struct Cache{T<:Function, I<:Unsigned, O} <: AbstractCache
    name::String
    func::T
    cache::Dict{I, O}
    filename::String                    # file name
    offsets::Dict{I, Tuple{Int, Int}}   # existing hash - to - file positions
end



# Function that generates a name based on the name of the cached function
function generate_cache_filename(fname::String)
    _filename = "_" * string(hash(fname), base=16) * "_.bin"
    return abspath(_filename)
end



# Overload constructor
Cache(f::T where T<:Function;
		  name::String = string(f),
		  filename::String = generate_cache_filename(name),
		  input_type::Type=UInt,
		  output_type::Type=Any) = begin
    Cache(name, f, Dict{input_type, output_type}(),
              abspath(filename),
              Dict{input_type, Tuple{Int, Int}}())
end



# Show method
show(io::IO, cache::Cache) = begin
    _msz = length(cache.cache)
    _dsz = length(cache.offsets)
    _tsz = length(symdiff(keys(cache.cache), keys(cache.offsets))) +
           length(intersect(keys(cache.cache), keys(cache.offsets)))
    _en = ifelse(_tsz == 1, "entry", "entries")
    print(io, "$(cache.name) (cache with $_tsz $_en, $_msz in memory $_dsz on disk)")
end



# Call method (caches only to memory, caching to disk has to be explicit)
(cache::Cache{T, I, O})(args...; kwargs...) where {T, I, O} = begin
    _hash = arghash(args...; kwargs...)
    _, decompressor = get_transcoders(cache.filename)
    if _hash in keys(cache.cache)
        return cache.cache[_hash]
    elseif _hash in keys(cache.offsets)
        @warn "Memory cache miss, loading hash=0x$(string(_hash, base=16))..."
        open(cache.filename, "r") do fid
            startpos = cache.offsets[_hash][1]
            endpos = cache.offsets[_hash][2]
            datum = load_disk_cache_entry(fid, startpos, endpos,
                                          decompressor=decompressor)
            return datum::O
        end
    else
        @debug "Full cache miss, adding hash=0x$(string(_hash, base=16))..."
        # Check that the output type matches
        if !(return_type(cache.func, typeof.(args)) <: O)
            throw(AssertionError("Output type is not a subtype $O"))
        end
        out = cache.func(args...; kwargs...)
        cache.cache[_hash] = out
        return out
    end
end



# Macros
# TODO(Corneliu): Support julia> @cache foo(x) = begin ... end and other
#   method and function definition forms
# Macro supporting construnctions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @cache foo # now `fooc` is the cached version of `foo`
macro cache(symb::Symbol, filename::String=generate_cache_filename(string(symb)))
    _name = String(symb)
    ex = quote
        try
            Cache($symb,
                      name=$_name,
                      filename=$filename)
        catch excep
            @error "Could not create Cache. $excep"
        end
    end
    return esc(ex)
end  # macro



# Macro supporting constructions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @cache foo::Int  # expects output to be `Int`
macro cache(expr::Expr, filename::String=generate_cache_filename(string(expr.args[1])))
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
            Cache($_symb,
                      name=$_name,
                      filename=$filename,
                      output_type=$_type)
        catch excep
            @error "Could not create Cache. $excep"
        end
    end
    return esc(ex)
end  # macro
