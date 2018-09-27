# Abstraction of size information
abstract type AbstractSize end

struct CountSize <: AbstractSize
    val::Int  # objects
end

struct MemorySize <: AbstractSize
    val::Int  # bytes
end



show(io::IO, sz::CountSize) =
    sz.val == 1 ? print(io, "1 object") : print(io, "$(sz.val) objects")

show(io::IO, sz::MemorySize) = print(io, "$(sz.val/1024) KiB")



object_size(dd::Dict, ::Type{CountSize}) = length(dd)

object_size(dd::Dict, ::Type{MemorySize}) =
    isempty(dd) ? 0 : mapreduce(x->summarysize(x), +, values(dd))

object_size(object, ::Type{CountSize}) = 1

object_size(object, ::Type{MemorySize}) = summarysize(object)



# Cache struct
abstract type AbstractCache end

mutable struct Cache{T<:Function, I<:Unsigned, O, S<:AbstractSize} <: AbstractCache
    name::String                        # name of the object
    filename::String                    # file name
    func::T
    cache::Dict{I, O}
    offsets::Dict{I, Tuple{Int, Int}}   # existing hash - to - file positions
    history::Deque{I}                   # A deque of hashes
    max_size::S
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
	  output_type::Type=Any,
      max_size::S=CountSize(MAX_CACHE_SIZE)) where {F<:Function, S<:AbstractSize} =
    # The main constructor call (separating comment ;)
    Cache(name, abspath(filename), f, Dict{input_type, output_type}(),
          Dict{input_type, Tuple{Int, Int}}(), Deque{input_type}(),
          max_size)



# Show method
show(io::IO, cache::Cache) = begin
    _msz = length(cache.cache)
    _dsz = length(cache.offsets)
    _tsz = length(symdiff(keys(cache.cache), keys(cache.offsets))) +
           length(intersect(keys(cache.cache), keys(cache.offsets)))
    _en = ifelse(_tsz == 1, "entry", "entries")
    print(io, "$(cache.name) (cache with $_tsz $_en, $_msz in memory $_dsz on disk)")
end



# Other useful functions
length(cache::Cache) = length(cache.cache)

max_cache_size(cache::Cache) = cache.max_size.val

object_size(cache::Cache{T, I, O, S}) where {T<:Function, I, O, S <: AbstractSize} =
    object_size(cache.cache, S)



# Call method (caches only to memory, caching to disk has to be explicit)
function (cache::Cache{T, I, O, S})(args...; kwargs...) where
        {T<:Function, I<:Unsigned, O, S<:AbstractSize}
    _hash = arghash(args...; kwargs...)
    _, decompressor = get_transcoders(cache.filename)
    if _hash in keys(cache.cache)
        # Move hash from oldest to most recent
        # so that the next entry does not remove it;
        # return the cached value
        if max_cache_size(cache) <= object_size(cache) && front(cache.history) == _hash
            push!(cache.history, _hash)
            popfirst!(cache.history)
        end
        return cache.cache[_hash]
    elseif _hash in keys(cache.offsets)
        # Entries found only on disk do not update the history,
        # this is just a load operation; only an explicit synchonization
        # will load into memory
        @warn "Memory cache miss, loading hash=0x$(string(_hash, base=16))..."
        open(cache.filename, "r") do fid
            startpos = cache.offsets[_hash][1]
            endpos = cache.offsets[_hash][2]
            datum = load_disk_cache_entry(fid, startpos, endpos,
                                          decompressor=decompressor)
            if !(typeof(datum) <: O)
                throw(AssertionError("Output type is not a subtype $O"))
            end
            return datum
        end
    else
        # A hash miss: a new value must be cached. This requires a check
        # of the size of the returned object and dynamic removal of existing
        # entries if the maximum size is reached.
        @debug "Full cache miss, adding hash=0x$(string(_hash, base=16))..."
        # Check that the output type matches
        if !(return_type(cache.func, typeof.(args)) <: O)
            throw(AssertionError("Output type is not a subtype $O"))
        end
        out = cache.func(args...; kwargs...)
        while object_size(cache) + object_size(out, S) > max_cache_size(cache)
            delete!(cache.cache, popfirst!(cache.history))
        end
        cache.cache[_hash] = out
        push!(cache.history, _hash)
        return out
    end
end



# Macros
# TODO(Corneliu): Support julia> @cache foo(x) = begin ... end and other
#   method and function definition forms
# Macro supporting construnctions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @cache foo # now `fooc` is the cached version of `foo`
macro cache(symb::Symbol, filename::String=generate_cache_filename(string(symb)),
            max_size::Number=MAX_CACHE_SIZE)
    _name = String(symb)
    @assert max_size > 0 "The maximum size has to be > 0 (objects or KiB)."
    if max_size isa Int
        _max_size = CountSize(max_size)
    elseif max_size isa Real
        _max_size = MemorySize(max_size*1024)
    else
        @error "The maximum size has to be an Int or a Float64."
    end
    ex = quote
        try
            Cache($symb, name=$_name, filename=$filename, max_size=$_max_size)
        catch excep
            @error "Could not create Cache. $excep"
        end
    end
    return esc(ex)
end  # macro



# Macro supporting constructions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @cache foo::Int  # expects output to be `Int`
macro cache(expr::Expr,
            filename::String=generate_cache_filename(string(expr.args[1])),
            max_size::Number=MAX_CACHE_SIZE)
    # Parse
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

    @assert max_size > 0 "The maximum size has to be > 0 (objects or KiB)."
    if max_size isa Int
        _max_size = CountSize(max_size)
    elseif max_size isa Real
        _max_size = MemorySize(max_size*1024)
    else
        @error "The maximum size has to be an Int or a Float64."
    end

    ex = quote
        try
            Cache($_symb, name=$_name, filename=$filename, output_type=$_type,
                 max_size=$_max_size)
        catch excep
            @error "Could not create Cache. $excep"
        end
    end
    return esc(ex)
end  # macro
