# Memory caching (dictionary based)

mutable struct MemoryCache{T<:Function, I<:Unsigned, O} <: AbstractCache
    name::String
    func::T
    cache::Dict{I, O}
end


# Overload constructor
MemoryCache(f::T where T<:Function;
			name::String = string(f),
			input_type::Type=UInt64,
			output_type::Type=Any) =
	MemoryCache(name, f, Dict{input_type, output_type}())


# Call method
(mc::T where T<:MemoryCache)(args...; kwargs...) = begin
    _hash = hash([map(hash, args)..., map(hash, collect(kwargs))...])
    if _hash in keys(mc.cache)
        out = mc.cache[_hash]
    else
        @info "Hash miss, caching hash=$_hash..."
        out = mc.func(args...; kwargs...)
        mc.cache[_hash] = out
    end
    return out
end


# Show method
show(io::IO, c::MemoryCache) = begin
    println(io, "Memory cache for \"$(c.name)\" " *
            "with $(length(c.cache)) entries.")
end


# Macros

# Macro supporting construnctions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @memcache foo # now `fooc` is the cached version of `foo`
macro memcache(symb::Symbol)
    @assert isdefined(Main, symb)
    _name = String(symb)
    ex = quote
        try
            MemoryCache($symb, name=$_name)
        catch excep
            @error "Could not create MemoryCache. $excep"
        end
    end
    return esc(ex)
end  # macro


# Macro supporting constructions of the form:
# 	julia> foo(x) = x+1
# 	julia> fooc = @memcache foo::Int  # expects output to be `Int`
macro memcache(expr::Expr)
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
            MemoryCache($_symb, name=$_name, output_type=$_type)
        catch excep
            @error "Could not create MemoryCache. $excep"
        end
    end
    return esc(ex)
end  # macro
