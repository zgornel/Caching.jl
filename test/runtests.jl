using Test
using Random
using LRUCaching

_a_float = rand()
_a_float_2 = rand()
_an_int = rand(Int)
function foo(x)
	return x
end

# Test MemoryCache, @memcahe

@testset "Memory caching" begin
    # Test caching of simple functions
    foo_c1 = LRUCaching.MemoryCache(foo)
    @test typeof(foo_c1) <: LRUCaching.AbstractCache
    @test typeof(foo_c1) <: LRUCaching.MemoryCache
    @test foo(_a_float) == foo_c1(_a_float)

    # Test functions with keyword arguments
    function bar(x; y=1)
    	return x+y
    end
    bar_c1 = LRUCaching.MemoryCache(bar)
    @test typeof(bar_c1) <: LRUCaching.AbstractCache
    @test typeof(bar_c1) <: LRUCaching.MemoryCache
    @test bar(_a_float) == bar_c1(_a_float)
    @test bar(_a_float; y=_a_float_2) == bar_c1(_a_float; y=_a_float_2)

	# Test macro support
    foo_m1 = @memcache foo			# no type annotations
	foo_m2 = @memcache foo::Int		# standard type annotation
	for _foo in (foo_m1, foo_m2)
    	@test typeof(_foo) <: LRUCaching.AbstractCache
    	@test typeof(_foo) <: LRUCaching.MemoryCache
		@test _foo(_an_int) == foo(_an_int)	 # all should work with Int's
		if !(_foo === foo_m1)
		# `foo_m2` fails with arguments other than `Int`
			try
				_foo(_a_float)
				@test false
			catch
				@test _foo.cache isa Dict{Vector{UInt64}, Int}
			end
		else
			@test _foo(_a_float) == foo(_a_float)
			@test _foo.cache isa Dict{Vector{UInt64}, Any}
		end
	end
end
