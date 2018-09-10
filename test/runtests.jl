using Test
using Random
using LRUCaching

# Function arguments
_a_float = rand()
_a_float_2 = rand()
_an_int = rand(Int)

# Functions
function foo(x)
	return x
end

function bar(x; y=1)
	return x+y
end

# Test MemoryCache, @memcahe
@testset "Memory caching" begin
    # Test caching of simple functions
    foo_c1 = LRUCaching.MemoryCache(foo)
    @test typeof(foo_c1) <: LRUCaching.AbstractCache
    @test typeof(foo_c1) <: LRUCaching.MemoryCache
    @test foo(_a_float) == foo_c1(_a_float)

    # Test functions with keyword arguments
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
				@test _foo.cache isa Dict{UInt64, Int}
			end
		else
			@test _foo(_a_float) == foo(_a_float)
			@test _foo.cache isa Dict{UInt64, Any}
		end
	end
end


# Test DiskCache, @diskcache
@testset "Disk caching" begin
    # Test caching of simple functions
    foo_c1 = LRUCaching.DiskCache(foo)
    @test typeof(foo_c1) <: LRUCaching.AbstractCache
    @test typeof(foo_c1) <: LRUCaching.DiskCache
    @test typeof(foo_c1.memcache) <: LRUCaching.MemoryCache
	@test :filename in fieldnames(typeof(foo_c1))
    @test foo(_a_float) == foo_c1(_a_float)

    # Test functions with keyword arguments
    bar_c1 = LRUCaching.DiskCache(bar)
    @test typeof(bar_c1) <: LRUCaching.AbstractCache
    @test typeof(bar_c1) <: LRUCaching.DiskCache
    @test typeof(bar_c1.memcache) <: LRUCaching.MemoryCache
	@test :filename in fieldnames(typeof(bar_c1))
    @test bar(_a_float) == bar_c1(_a_float)
    @test bar(_a_float; y=_a_float_2) == bar_c1(_a_float; y=_a_float_2)

	# Test macro support
    foo_m1 = @diskcache foo			# no type annotations
	foo_m2 = @diskcache foo::Int	# standard type annotation
	for _foo in (foo_m1, foo_m2)
    	@test typeof(_foo) <: LRUCaching.AbstractCache
    	@test typeof(_foo) <: LRUCaching.DiskCache
    	@test typeof(_foo.memcache) <: LRUCaching.MemoryCache
		@test :filename in fieldnames(typeof(_foo))
		@test _foo(_an_int) == foo(_an_int)	 # all should work with Int's
		if !(_foo === foo_m1)
		# `foo_m2` fails with arguments other than `Int`
			try
				_foo(_a_float)
				@test false
			catch
				@test _foo.memcache.cache isa Dict{UInt64, Int}
			end
		else
			@test _foo(_a_float) == foo(_a_float)
			@test _foo.memcache.cache isa Dict{UInt64, Any}
		end
	end
end


# Test Utils
