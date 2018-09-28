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

mutable struct Cache{T<:Function, O, S<:AbstractSize} <: AbstractCache
    name::String                            # name of the object
    filename::String                        # file name
    func::T                                 # function being cached
    cache::Dict{UInt, O}                    # cache dictionary
    offsets::Dict{UInt, Tuple{UInt, UInt}}  # existing hash - to - file positions
    history::Deque{UInt}                    # order in which the calls were executed (by hash)
    max_size::S                             # maximum size of the cache
end



# Overload constructor
Cache(f::T where T<:Function;
      name::String = string(f),
	  filename::String = generate_cache_filename(name),
	  output_type::Type=Any,
      max_size::S=CountSize(MAX_CACHE_SIZE)) where {F<:Function, S<:AbstractSize} =
    # The main constructor call (separating comment ;)
    Cache(name, abspath(filename), f, Dict{UInt, output_type}(),
          Dict{UInt, Tuple{UInt, UInt}}(), Deque{UInt}(),
          max_size)



# Show method
show(io::IO, cache::Cache) = begin
    memory_size = length(cache.cache)
    disk_size = length(cache.offsets)
    total_size = length(symdiff(keys(cache.cache), keys(cache.offsets))) +
        length(intersect(keys(cache.cache), keys(cache.offsets)))
    _en = ifelse(total_size == 1, "entry", "entries")
    print(io, "$(cache.name) (cache with $total_size $_en, ",
              "$memory_size in memory $disk_size on disk)")
end



# Other useful functions
length(cache::Cache) = length(cache.cache)

max_cache_size(cache::Cache) = cache.max_size.val

object_size(cache::Cache{T, O, S}) where {T<:Function, O, S<:AbstractSize} =
    object_size(cache.cache, S)



# Call method (caches only to memory, caching to disk has to be explicit)
function (cache::Cache{T, O, S})(args...; kwargs...) where {T<:Function, O, S<:AbstractSize}
    # ~~ Caclculate hash ~~
    _Hash_ = arghash(args...; kwargs...)
    # ---
    _, decompressor = get_transcoders(cache.filename)
    if _Hash_ in keys(cache.cache)
        # Move hash from oldest to most recent
        # so that the next entry does not remove it;
        # return the cached value
        if max_cache_size(cache) <= object_size(cache) && front(cache.history) == _Hash_
            push!(cache.history, _Hash_)
            popfirst!(cache.history)
        end
        return cache.cache[_Hash_]
    elseif _Hash_ in keys(cache.offsets)
        # Entries found only on disk do not update the history,
        # this is just a load operation; only an explicit synchonization
        # will load into memory
        @warn "Memory cache miss, loading hash=0x$(string(_Hash_, base=16))..."
        open(cache.filename, "r") do fid
            startpos, endpos = cache.offsets[_Hash_]
            datum = load_disk_cache_entry(fid, startpos, endpos,
                                          decompressor=decompressor)
            if !(typeof(datum) <: O)
                throw(AssertionError("Output type is not a subtype $O"))
            end
            return datum::O
        end
    else
        # A hash miss: a new value must be cached. This requires a check
        # of the size of the returned object and dynamic removal of existing
        # entries if the maximum size is reached.
        @debug "Full cache miss, adding hash=0x$(string(_Hash_, base=16))..."
        # Check that the output type matches
        if !(return_type(cache.func, typeof.(args)) <: O)
            throw(AssertionError("Output type is not a subtype $O"))
        end
        out::O = cache.func(args...; kwargs...)
        while object_size(cache) + object_size(out, S) > max_cache_size(cache)
            delete!(cache.cache, popfirst!(cache.history))
        end
        cache.cache[_Hash_] = out
        push!(cache.history, _Hash_)
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
