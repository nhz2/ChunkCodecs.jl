module ChunkCodecTests

using ChunkCodecCore:
    Codec,
    EncodeOptions,
    DecodeOptions,
    codec,
    is_thread_safe,
    can_concatenate,
    decode_options,
    decoded_size_range,
    encoded_bound,
    encode,
    decode,
    DecodedSizeError,
    try_find_decoded_size,
    try_encode!,
    try_decode!,
    try_resize_decode!

using Test: Test, @test, @test_throws

export test_codec

function test_codec(c::Codec, e::EncodeOptions, d::DecodeOptions; trials=100)
    @test decode_options(c) isa DecodeOptions
    @test codec(e) == c
    @test codec(d) == c
    @test is_thread_safe(e) isa Bool
    @test is_thread_safe(d) isa Bool

    @test decoded_size_range(e) isa StepRange{Int64, Int64}

    srange = decoded_size_range(e)
    @test !isempty(srange)
    @test step(srange) > 0
    @test first(srange) ≥ 0
    @test last(srange) != typemax(Int64) # avoid length overflow

    for s in [first(srange):step(srange):min(last(srange), 1000); rand(srange, 10000); last(srange)]
        @test encoded_bound(e, s) isa Int64
        @test encoded_bound(e, s) ≥ s
    end

    # round trip tests
    decoded_sizes = [
        first(srange):step(srange):min(last(srange), first(srange)+10*step(srange));
        rand(first(srange):step(srange):min(last(srange), 2000000), trials);
    ]
    for s in decoded_sizes
        # generate data
        local choice = rand(1:4)
        local data = if choice == 1
            rand(UInt8, s)
        elseif choice == 2
            zeros(UInt8, s)
        elseif choice == 3
            ones(UInt8, s)
        elseif choice == 4
            rand(0x00:0x0f, s)
        end
        local e_bound = encoded_bound(e, s)
        local encoded = encode(e, data)
        local buffer = rand(UInt8, max(length(encoded)+11, e_bound+11))
        local b_copy = copy(buffer)
        for buffer_size in [length(encoded):length(encoded)+11; max(e_bound-11,0):e_bound+11;]
            buffer .= b_copy
            local encoded_size = try_encode!(e, view(buffer,1:buffer_size), data)
            # try to test no out of bounds writing
            @test @view(buffer[buffer_size+1:end]) == @view(b_copy[buffer_size+1:end])
            if !isnothing(encoded_size)
                @test decode(d, view(buffer, 1:encoded_size)) == data
            else
                @test buffer_size < e_bound
            end
        end
        # @test try_encode!(e, zeros(UInt8, length(encoded)+1), data) === length(encoded)
        if length(encoded) > 0
            @test isnothing(try_encode!(e, zeros(UInt8, length(encoded)-1), data))
        end
        local ds = try_find_decoded_size(d, encoded)
        @test ds isa Union{Nothing, Int64}
        if !isnothing(ds)
            @test ds === s
        end
        local dst = zeros(UInt8, s)
        @test try_decode!(d, dst, encoded) === s
        @test dst == data
        if s > 0
            dst = zeros(UInt8, s - 1)
            @test isnothing(try_decode!(d, dst, encoded))
            @test isnothing(try_decode!(d, UInt8[], encoded))
        end
        dst = zeros(UInt8, s + 1)
        @test try_decode!(d, dst, encoded) === s
        @test length(dst) == s + 1
        @test dst[1:s] == data

        if s > 0
            dst = zeros(UInt8, s - 1)
            @test_throws(
                ArgumentError("`max_size`: $(-1) must be at least `length(dst)`: $(s-1)"),
                try_resize_decode!(d, dst, encoded; max_size=Int64(-1))
            )
            dst = zeros(UInt8, s - 1)
            @test try_resize_decode!(d, dst, encoded; max_size=s) == s
            @test length(dst) == s
            @test dst == data
            dst = UInt8[]
            @test isnothing(try_resize_decode!(d, dst, encoded; max_size=Int64(0)))
        end
        if s > 1
            dst = UInt8[]
            @test isnothing(try_resize_decode!(d, dst, encoded; max_size=Int64(1)))
            dst = UInt8[0x01]
            @test isnothing(try_resize_decode!(d, dst, encoded; max_size=Int64(1)))
            @test_throws DecodedSizeError(1, try_find_decoded_size(d, encoded)) decode(d, encoded; max_size=Int64(1))
        end
        dst_buffer = zeros(UInt8, s + 2)
        dst = view(dst_buffer, 1:s+1)
        @test_throws(
            ArgumentError("`max_size`: $(s) must be at least `length(dst)`: $(s+1)"),
            try_resize_decode!(d, dst, encoded; max_size=s),
        )
        @test try_resize_decode!(d, dst, encoded; max_size=s+2) === s
        @test length(dst) == s + 1
        @test dst[1:s] == data
        @test dst_buffer[end] == 0x00

        @test decode(d, encoded) == data
    end

    # can_concatenate tests
    if can_concatenate(c)
        a = rand(UInt8, 100*step(srange))
        b = rand(UInt8, 200*step(srange))
        @test decode(d, [encode(e, a); encode(e, b);]) == [a; b;]
        @test decode(d, [encode(e, UInt8[]); encode(e, UInt8[]);]) == UInt8[]
    end
end

"""
    last_good_input(f)

Return the max value of `x` where `f(x::Int64)` doesn't error
`f` must be monotonically increasing
"""
function last_good_input(f)
    low::Int64 = 0
    high::Int64 = typemax(Int64)
    while low != high - 1
        x = (low+high)>>>1
        try
            f(x)
            low = x
        catch
            high = x
        end
    end
    low
end

function find_max_decoded_size(e::EncodeOptions)
    last_good_input(x->encoded_bound(e, x))
end

end # module ChunkCodecTests
