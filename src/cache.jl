# Abstraction of size information
abstract type AbstractSize end

struct CountSize <: AbstractSize
    val::Int  # objects
end

struct MemorySize <: AbstractSize
    val::Int  # bytes
end



# show methods
show(io::IO, sz::CountSize) =
    sz.val == 1 ? print(io, "1 object") : print(io, "$(sz.val) objects")

show(io::IO, sz::MemorySize) = print(io, "$(sz.val/1024) KiB")


# Object size
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
	  filename::String = generate_cache_filename(),
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
    __hash__ = arghash(args...; kwargs...)
    # ~~~
    _, decompressor = get_transcoders(cache.filename)
    if haskey(cache.cache, __hash__)
        # Move hash from oldest to most recent
        # so that the next entry does not remove it;
        # return the cached value
        if max_cache_size(cache) <= object_size(cache) && front(cache.history) == __hash__
            push!(cache.history, __hash__)
            popfirst!(cache.history)
        end
        return cache.cache[__hash__]
    elseif haskey(cache.offsets, __hash__)
        # Entries found only on disk do not update the history,
        # this is just a load operation; only an explicit synchonization
        # will load into memory
        @debug "Memory cache miss, loading hash=0x$(string(__hash__, base=16))..."
        open(cache.filename, "r") do fid
            startpos, endpos = cache.offsets[__hash__]
            datum = load_disk_cache_entry(fid, startpos, endpos, decompressor)
            if !(typeof(datum) <: O)
                throw(AssertionError("Output type is not a subtype $O"))
            end
            return datum::O
        end
    else
        # A hash miss: a new value must be cached. This requires a check
        # of the size of the returned object and dynamic removal of existing
        # entries if the maximum size is reached.
        @debug "Full cache miss, adding hash=0x$(string(__hash__, base=16))..."
        # Check that the output type matches
        if !(return_type(cache.func, typeof.(args)) <: O)
            throw(AssertionError("Output type is not a subtype $O"))
        end
        # Run function
        out::O = cache.func(args...; kwargs...)
        # Check if cache is full when limit set in KiB
        if S<:MemorySize && object_size(out,S) > max_cache_size(cache)  # check for memory
            @warn "Cannot cache result of size $(S(object_size(out,S))) " *
            "(maximum cache size is $(cache.max_size))."
            return out
        end
        # Delete objects and cache
        while object_size(cache) + object_size(out, S) > max_cache_size(cache)
            delete!(cache.cache, popfirst!(cache.history))
        end
        cache.cache[__hash__] = out
        push!(cache.history, __hash__)
        return out
    end
end



# @cache macro
macro cache(expression, filename::String=generate_cache_filename(), max_size::Number=MAX_CACHE_SIZE)
    # Check size, no need to check the filename
    @assert max_size > 0 "The maximum size has to be > 0 (objects or KiB)."
    if max_size isa Int
        _max_size = CountSize(max_size)
    elseif max_size isa Real
        _max_size = MemorySize(max_size*1024)
    else
        @error "The maximum size has to be an Int or a Float64."
    end

    # Parse macro input
    if expression isa Symbol
        #######################
        # julia> @cache foo   #-> foo remains a function, new Cache object returned
        #######################
        _name = String(expression)
        ex = quote
                Cache($expression, name=$_name, filename=$filename, max_size=$_max_size)
        end
    elseif expression isa Expr && expression.head == :(::) && length(expression.args) == 2
        ############################
        # julia> @cache foo::Int   #-> foo remains a function, new Cache object returned
        ############################
        _symb = expression.args[1]
        _typesymbol = expression.args[2]
        _type = eval(_typesymbol)
        _name = String(_symb)
        @assert _type isa Type "The right-hand argument of `::` is not a type."
        ex = quote
                Cache($_symb, name=$_name,
                      filename=$filename,
                      output_type=$_type,
                     max_size=$_max_size)
        end
    elseif expression isa Expr && expression.head == :(=)
        #############################
        # julia> @cache foo=x->x+1  #-> foo becomes a Caching.Cache object
        #############################
        f_output_type = Any
        if @capture(expression, f_name_ = arg_::input_type_->body_)
            if input_type == nothing
                input_type = Any
            end
        elseif @capture(expression, f_name_ = arg_->body_)
            input_type = Any
        else
            @error "Only one input argument lambdas are supported."
        end
        new_expression = :(($arg::$input_type)->$body)
        _func = eval(new_expression)
        _t = eval(input_type)
        ex = quote
            $f_name = Caching.Cache(eval($new_expression),
                                    name=$(string(f_name)),
                                    filename=$filename,
                                    output_type=Core.Compiler.return_type($_func,($_t,)),
                                    max_size=$_max_size)
        end

    else
        #######################################
        # julia> @cache function foo(x::Int)  #
        #                   x+1               #-> foo becomes a Caching.Cache object
        #               end                   #
        #######################################
        f_parsed = splitdef(expression)
        f_name = f_parsed[:name]
        f_output_type = get(f_parsed, :rtype, :Any)
        random_name = Symbol(:f_, randstring(20))
        new_definition = copy(f_parsed)
        new_f_name = random_name
        new_definition[:name] = new_f_name
        ex = quote
                $(MacroTools.combinedef(new_definition))  # reconstruct function def and run it
                $f_name = Caching.Cache($random_name,
                                        name=$(string(f_name)),
                                        filename=$filename,
                                        output_type=$f_output_type,
                                        max_size=$_max_size)
        end
    end
    return esc(ex)
end  # macro
