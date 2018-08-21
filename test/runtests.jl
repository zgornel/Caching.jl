using LRUCaching
using Test

function foo(x::Int)
	return x
end

foo_cache = LRUCaching.Cache(foo)

@assert foo(1) == foo_cache(1) 
