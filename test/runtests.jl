using Test
using Caching

# Make file
FILE, FILEid = mktemp()
close(FILEid)
_tmpdir = tempdir()

# Test Cache, @cache
@testset "Cache" begin
    # Function arguments
    _a_float = 0.1234
    _a_float_2 = 0.5678
    _an_int = 1234

    # Define functions
    global foo(x) = x
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
    foo_m1 = @eval @cache foo $FILE  # no type annotations
    foo_m2 = @eval @cache foo::Int $FILE  # standard type annotation
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

    dc = @eval @cache foo $(joinpath(_tmpdir,"somefile.bin"))
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
    fc = @eval @cache foo $FILE  # make a cache object
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

    dc =@eval @cache foo $FILE
    dc(1)
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
    global dc
    dc = @eval @cache foo $FILE
    @test dc.filename == abspath(FILE)
    @test isempty(dc.offsets)
    N = 3
    for i in 1:N dc(i); end  # add N entries

    @persist! dc
    @test length(dc.offsets) == N
    @test isfile(FILE)
    @test dc.filename == abspath(FILE)
    buf = open(read, FILE)
    rm(FILE)
    FILE2 = joinpath(_tmpdir, "some_other_file.bin")
    @eval @persist! dc $FILE2
    @test length(dc.offsets) == N
    @test isfile(FILE2)
    @test dc.filename == abspath(FILE2)
    buf2 = open(read, FILE2)
    rm(FILE2)

    @test buf == buf2  # sanity check
end



# Compression
@testset "Compression" begin
    files = joinpath.(_tmpdir, ["somefile.bin",
                                "somefile.bin.gz",
                                "somefile.bin.gzip",
                                "somefile.bin.bz2",
                                "somefile.bin.bzip2"])
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
@testset "Size constraints: number of objects" begin
    file = joinpath(_tmpdir, "somefile.bin")
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

@testset "Size constraints: bytes of memory" begin
    file = joinpath(_tmpdir, "somefile.bin")
    foo(x) = x
    dc = @eval @cache foo $file 1.0  # 1024 bytes=1.0 KiB max
    for i in 1:128 dc(i) end
    #--> Cache is full (128 x 8bytes/number=1024 bytes)
    dc(129)  #--> 1 is removed
    @test !(1 in values(dc.cache)) &&
        all(i in values(dc.cache) for i in 2:129)
    @persist! dc
    @empty! dc  #--> 2,...,129 on disk, nothing in memory
    for i in 130:130+126 dc(i) end  # write 127 entries
    #--> 130,..,256 in memory, 2,...,129 on disk
    @syncache! dc #--> brings 129 in memory and 130,...,256 on disk
    @test all(i in values(dc.cache) for i in 129:130+126)
    @test length(dc) == 128 # sanity check
    @empty! dc  #--> nothing in memory
    @syncache! dc "disk"  #--> load from disk max entries i.e. 128
    @test all(i in values(dc.cache) for i in 129:130+126)
    @empty! dc true  # remove everything
end



@testset "@cache <func. def.>" begin
    @test !@isdefined foo
    @cache foo=x->x
    @test @isdefined foo
    @test typeof(foo.cache) == Dict{UInt,Any}
    @test foo(1) == 1

    T = Int
    @test !@isdefined bar
    @eval @cache bar=x::$T->x
    @test @isdefined bar
    @eval @test typeof(bar.cache) == Dict{UInt,$T}
    @test bar(1) == 1

    @test !@isdefined baz
    @eval @cache function baz(x)::$T x end
    @test @isdefined baz
    @eval @test typeof(baz.cache) == Dict{UInt,$T}
    @test baz(1) == 1
end



# Hashing function
struct custom_type{T}
    x::T
end
@testset "Hashing function" begin
    num = 1
    str = "a string"
    # test hashing function for various objects
    for object in (Int(num), UInt(num), Float64(num),
                   [num num], (num, num),
                   str, [str, str], (str,str),
                   custom_type(num), custom_type(str),
                   [custom_type(num)], (custom_type(num),),
                   custom_type(custom_type(num))
                  )
        object2 = deepcopy(object)
        @test arghash(object) == arghash(object2)
    end
end



# show methods
@testset "Show methods" begin
    buf = IOBuffer()
    foo(x) = x
    dc = @eval @cache foo $FILE
    try
        show(buf, dc)
        @test true
    catch
        @test false
    end
end
