using LRUCaching
using Random
using Test

number1 = rand()
number2 = rand()

function foo(x)
	return x
end


foo_c1 = LRUCaching.MemoryCache(foo)
@assert typeof(foo_c1) <: LRUCaching.AbstractCache
@assert typeof(foo_c1) <: LRUCaching.MemoryCache
@assert foo(number1) == foo_c1(number1)

foo_m1 = @memcache foo
@assert typeof(foo_m1) <: LRUCaching.MemoryCache
@assert foo(number1) == foo_m1(number1)


function bar(x; y=1)
	return x+y
end
bar_c1 = LRUCaching.MemoryCache(bar)
@assert typeof(bar_c1) <: LRUCaching.AbstractCache
@assert typeof(bar_c1) <: LRUCaching.MemoryCache
@assert bar(number1) == bar_c1(number1)
@assert bar(number1; y=number2) == bar_c1(number1; y=number2)
