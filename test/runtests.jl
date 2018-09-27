using Test
using Random
using Caching


# Test Cache, @cache
@testset "Cache" begin
    # Function arguments
    _a_float = rand()
    _a_float_2 = rand()
    _an_int = rand(Int)

    # Define functions
    foo(x) = x
    bar(x; y=1) = x + y

    # Test caching of simple functions
    foo_c1 = Cache(foo)
    @test typeof(foo_c1) <: AbstractCache
    @test typeof(foo_c1) <: Cache
    @test typeof(foo_c1.cache) <: Dict
    @test typeof(foo_c1.offsets) <: Dict
    @test typeof(foo_c1.filename) <: AbstractString
    @test typeof(foo_c1.name) <: AbstractString
    @test typeof(foo_c1.func) <: Function
    @test foo_c1.func == foo
    @test foo(_a_float) == foo_c1(_a_float)
    @test length(foo_c1.cache) == 1

    # Test functions with keyword arguments
    bar_c1 = Cache(bar)
    @test typeof(bar_c1) <: AbstractCache
    @test typeof(bar_c1) <: Cache
    @test typeof(bar_c1.cache) <: Dict
    @test typeof(bar_c1.offsets) <: Dict
    @test typeof(bar_c1.filename) <: AbstractString
    @test typeof(bar_c1.name) <: AbstractString
    @test typeof(bar_c1.func) <: Function
    @test bar_c1.func == bar
    @test bar(_a_float) == bar_c1(_a_float)
    @test bar(_a_float; y=_a_float_2) == bar_c1(_a_float; y=_a_float_2)
    @test length(bar_c1.cache) == 2

	# Test macro support
    foo_m1 = @cache foo			# no type annotations
	foo_m2 = @cache foo::Int	# standard type annotation
	for _foo in (foo_m1, foo_m2)
    	@test typeof(_foo) <: AbstractCache
    	@test typeof(_foo) <: Cache
        @test typeof(_foo.cache) <: Dict
        @test typeof(_foo.offsets) <: Dict
        @test typeof(_foo.filename) <: AbstractString
        @test typeof(_foo.name) <: AbstractString
        @test typeof(_foo.func) <: Function
        @test _foo.func == foo
		@test _foo(_an_int) == foo(_an_int)	 # all should work with Int's
		if !(_foo === foo_m1)
		# `foo_m2` fails with arguments other than `Int`
		    @test_throws AssertionError _foo(_a_float)
	        @test _foo.cache isa Dict{UInt64, Int}
		else
			@test _foo(_a_float) == foo(_a_float)
			@test _foo.cache isa Dict{UInt64, Any}
		end
	end

    dc = @cache foo "somefile.bin"
    for i in 1:3 dc(i); end
    @persist! dc
    @empty! dc
    @test length(dc.offsets) == 3
    @test isempty(dc.cache)
    for i in 4:6 dc(i); end
    for i in 1:6
        @test dc(i) == foo(i) == i
    end
    @empty! dc true
end


# syncache!, @syncache!
@testset "syncache!, @syncache!" begin
    # Define functions
    foo(x) = x+1  # define function
    
    n1 = 5
    fc = @cache foo "somefile.bin"  # make a cache object
    [fc(i) for i in 1:n1]  # populate the memorycache
    @persist! fc  # write to disk the cache
    @empty! fc  # delete the memory cache
    @test isempty(fc.cache)
    @syncache! fc "disk"  # load cache from disk
    @test isfile(fc.filename)
    @test length(fc.cache) == n1
    @empty! fc  # 5 entries on disk, 0 in memory

    n2 = 3
    [fc(-i) for i in 1:n2]  # populate the memory cache
    @syncache! fc "memory"  # write memory cache to disk
    @test length(fc.cache) == n2
    @empty! fc
    @test isempty(fc.cache)
    @syncache! fc "disk"    # load cache from disk
    @test length(fc.cache) == n1 + n2
    @empty! fc true  # remove everything

    [fc(i) for i in 1:n1]  # populate the memory cache
    @syncache! fc "memory"  # write to disk
    @empty! fc
    [fc(-i) for i in 1:n1]  # populate the memory cache
    @syncache! fc "both"     # sync both memory and disk
    @test length(fc.offsets) == 2*n1
    @test length(fc.cache) == 2*n1
    @empty! fc true
    @test !isfile(fc.filename)
end


# empty!, @empty!
@testset "empty!, @empty!" begin
    # Define functions
    foo(x) = x
    bar(x; y=1) = x + y

    dc = @cache foo; dc(1)
    @test length(dc.cache) == 1
    @persist! dc "somefile.bin"
    @test length(dc.offsets) == 1
    @test isfile("somefile.bin")
    @empty! dc true  # remove offsets and file
    @test isempty(dc.cache)
    @test isempty(dc.offsets)
    @test !isfile("somefile.bin")
end


# persist!, @persist!
@testset "persist!, @persist!" begin
    # Define functions
    foo(x) = x

    dc = @cache foo "somefile.bin"
    @test dc.filename == abspath("somefile.bin")
    @test isempty(dc.offsets)
    N = 3
    for i in 1:N dc(i); end  # add N entries

    @persist! dc
    @test length(dc.offsets) == N
    @test isfile("somefile.bin")
    @test dc.filename == abspath("somefile.bin")
    buf = open(read, "somefile.bin")
    rm("somefile.bin")

    @persist! dc "some_other_file.bin"
    @test length(dc.offsets) == N
    @test isfile("some_other_file.bin")
    @test dc.filename == abspath("some_other_file.bin")
    buf2 = open(read, "some_other_file.bin")
    rm("some_other_file.bin")

    @test buf == buf2  # sanity check
end


# Compression
@testset "Compression" begin
    files = ["somefile.bin",
             "somefile.bin.gz",
             "somefile.bin.gzip",
             "somefile.bin.bz2",
             "somefile.bin.bzip2",
            ]
    for _file in files
        global foo(x) = x
        dc = @eval @cache foo $_file
        data = [1,2,3]
        dc(data)
        @persist! dc
        @empty! dc
        try
            @test dc(data) == foo(data)
            @test true
        catch
            @test false
        end
        @empty! dc true
    end
end


# Size constraints 
@testset "Size constraints" begin
    file = "somefile.bin"
    foo(x) = x
    dc = @eval @cache foo $file 3  # 3 objects max
    dc(1)
    dc(2)
    dc(3)
    #--> Cache is full
    dc(4)  #--> 1 is removed
    @test !(1 in values(dc.cache)) &&
        all(i in values(dc.cache) for i in 2:4)
    @persist! dc
    @empty! dc
    for i in 5:6 dc(i) end
    #--> 2,3,4 on disk, 5,6 in memory
    @syncache! dc #--> brings 4 in memory and 5,6 on disk
    @test all(i in values(dc.cache) for i in 4:6)
    @test length(dc) == 3 # sanity check
    @empty! dc  #--> nothing in memory
    @syncache! dc "disk"  #--> load from disk max entries i.e. 3
    @test all(i in values(dc.cache) for i in 4:6)
    @empty! dc true  # remove everything
end
# show methods
@testset "Show methods" begin
    buf = IOBuffer()
    foo(x) = x
    dc = @cache foo "somefile.bin"
    try
        show(buf, dc)
        @test true
    catch
        @test false
    end
end
