using Test
using Random
using LRUCaching

# Function arguments
_a_float = rand()
_a_float_2 = rand()
_an_int = rand(Int)

N = 3

# Functions
function foo(x)
	return x
end

function bar(x; y=1)
	return x+y
end

# Test MemoryCache, @memcahe
@testset "MemoryCache" begin
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
@testset "DiskCache" begin
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


# Test functionality contained in the utils
@testset "Conversion constructors" begin
    _tmpfile = "_tmpfile.bin"
    foo(x) = x+1
    bar(x) = x-1

    # Construct cache objects using macros
    mc = @memcache bar
    dc = @diskcache foo

    # Construct cache objects using conversions
    mc_t = MemoryCache(dc)
    dc_t1 = DiskCache(mc)
    dc_t2 = DiskCache(mc, filename=_tmpfile)

    # Fill the cache
    for i in 1:N
        mc_t(rand())
        dc_t1(rand())
        dc_t2(rand())
    end

    # Tests for the MemoryCache object
    @test typeof(mc_t) <: MemoryCache
    @test length(mc_t.cache) == N
    @test mc_t.func === foo

    # Test for the DiskCache object
    @test typeof(dc_t1) <: DiskCache
    @test typeof(dc_t2) <: DiskCache
    @test :offsets in fieldnames(typeof(dc_t1))
    @test :offsets in fieldnames(typeof(dc_t2))
    @test dc_t1.memcache.func === bar
    @test dc_t2.memcache.func === bar
    @test length(dc_t1.memcache.cache) == N
    @test length(dc_t2.memcache.cache) == N
    @test dc_t2.filename == _tmpfile
    @test !(mc_t === dc.memcache)
end


# TODO(Corneliu): test synccache!, @synccache
@testset "syncache!, @syncache" begin
end

# empty!, @empty
@testset "empty!, @empty" begin
    mc = @memcache foo; mc(1)
    @test length(mc.cache) == 1
    @empty mc
    @test isempty(mc.cache)

    dc = @diskcache foo; dc(1)
    @test length(dc.memcache.cache) == 1
    @persist dc "somefile.bin"
    @test length(dc.offsets) == 1
    @test isfile("somefile.bin")
    @empty dc true  # remove offsets and file
    @test isempty(dc.memcache.cache)
    @test !isfile("somefile.bin")
    @test isempty(dc.offsets)
end

# persist!, @persist
@testset "persist!, @persist" begin
    mc = @memcache foo
    dc = @diskcache foo "somefile.bin"
    @test dc.filename == abspath("somefile.bin")
    @test isempty(dc.offsets)
    for i in 1:N dc(i); mc(i) end  # add N entries

    _path, _offsets = @persist mc "memfile.bin"
    @test isabspath(_path)
    @test typeof(_offsets) <: Dict{<:Unsigned, <:Tuple{Int, Int}}
    @test length(_offsets) == N
    @test isfile("memfile.bin")
    rm("memfile.bin")

    @persist dc
    @test length(dc.offsets) == N
    @test isfile("somefile.bin")
    @test dc.filename == abspath("somefile.bin")
    buf = open(read, "somefile.bin")
    rm("somefile.bin")

    @persist dc "some_other_file.bin"
    @test length(dc.offsets) == N
    @test isfile("some_other_file.bin")
    @test dc.filename == abspath("some_other_file.bin")
    buf2 = open(read, "some_other_file.bin")
    rm("some_other_file.bin")

    @test buf == buf2  # sanity check
end
