using LRUCaching
using Random
using Test

number = rand()

function foo(x)
	return x
end

foo_cache = LRUCaching.Cache(foo)
@assert typeof(foo_cache) <: LRUCaching.Cache
@assert foo(number) == foo_cache(number) 

foo_macro_cache = @cache foo
@assert typeof(foo_macro_cache) <: LRUCaching.Cache
@assert foo(number) == foo_macro_cache(number) 

