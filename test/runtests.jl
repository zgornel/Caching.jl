using LRUCaching
using Random
using Test

number1 = rand()
number2 = rand()

function foo(x)
	return x
end


foo_c1 = LRUCaching.MemoryCache(foo)
@test typeof(foo_c1) <: LRUCaching.AbstractCache
@test typeof(foo_c1) <: LRUCaching.MemoryCache
@test foo(number1) == foo_c1(number1)

foo_m1 = @memcache foo
@test typeof(foo_m1) <: LRUCaching.MemoryCache
@test foo(number1) == foo_m1(number1)


function bar(x; y=1)
	return x+y
end
bar_c1 = LRUCaching.MemoryCache(bar)
@test typeof(bar_c1) <: LRUCaching.AbstractCache
@test typeof(bar_c1) <: LRUCaching.MemoryCache
@test bar(number1) == bar_c1(number1)
@test bar(number1; y=number2) == bar_c1(number1; y=number2)
