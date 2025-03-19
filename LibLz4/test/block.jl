using ChunkCodecCore: encode_bound, decoded_size_range, encode, decode, DecodedSizeError
using ChunkCodecLibLz4
using ChunkCodecTests: test_codec
using Test: @testset, @test_throws, @test

@testset "default" begin
    test_codec(LZ4BlockCodec(), LZ4BlockEncodeOptions(), LZ4BlockDecodeOptions(); trials = 100)
end
@testset "compressionLevel options" begin
    # Compression level is clamped
    for compressionLevel in [typemin(Int128); -30:13; typemax(Int128)]
        test_codec(
            LZ4BlockCodec(),
            LZ4BlockEncodeOptions(; compressionLevel),
            LZ4BlockDecodeOptions();
            trials=3,
        )
    end
end
@testset "unexpected eof" begin
    e = LZ4BlockEncodeOptions()
    d = LZ4BlockDecodeOptions()
    u = [0x00, 0x01, 0x02]
    c = encode(e, u)
    @test decode(d, c) == u
    for i in 1:length(c)
        @test_throws LZ4DecodingError("unexpected end of input") decode(d, c[1:i-1])
    end
    @test_throws LZ4DecodingError("offset is before the beginning of the output") decode(d, u)
end
@testset "dry_run_block_decode tests" begin
    f = ChunkCodecLibLz4.dry_run_block_decode
    d = LZ4BlockDecodeOptions()
    e = LZ4BlockEncodeOptions()

    @testset "zero and one byte cases" begin
        @test_throws LZ4DecodingError("unexpected end of input") f(UInt8[])
        @test encode(e, UInt8[]) == [0x00]
        @test f([0x00]) == 0
        for i in 0x01:0x0F
            @test_throws LZ4DecodingError("end of block condition 1 violated") f([i])
        end
        for i in 0x10:0xFF
            @test_throws LZ4DecodingError("unexpected end of input") f([i])
        end
    end
    @testset "two byte cases" begin
        for b0 in 0x00:0x0F
            for b1 in 0x00:0xFF
                @test_throws LZ4DecodingError("unexpected end of input") f([b0, b1])
            end
        end
        b0 = 0x10
        for b1 in 0x00:0xFF
            @test f([b0, b1]) == 1
        end
        for b0 in 0x11:0x1F
            for b1 in 0x00:0xFF
                @test_throws LZ4DecodingError("end of block condition 1 violated") f([b0, b1])
            end
        end
        for b0 in 0x20:0xFF
            for b1 in 0x00:0xFF
                @test_throws LZ4DecodingError("unexpected end of input") f([b0, b1])
            end
        end
    end
    @testset "max decoded size" begin
        max_cint_zeros = UInt8[0x1F;0x00;0x01;0x00;fill(0xFF,8421504);0x66;0x50;fill(0x00,5)]
        over_max_cint_zeros = UInt8[0x1F;0x00;0x01;0x00;fill(0xFF,8421504);0x67;0x50;fill(0x00,5)]
        @test f(max_cint_zeros) == typemax(Cint)
        @test f(over_max_cint_zeros) == Int64(typemax(Cint))+1
        @test_throws(
            LZ4DecodingError("actual decoded size > typemax(Int32): 2147483648 > 2147483647"),
            decode(d, over_max_cint_zeros; max_size=Int64(2)^24),
        )
        @test_throws(
            DecodedSizeError,
            decode(d, max_cint_zeros; max_size=Int64(2)^24),
        )
        @test_throws LZ4DecodingError("actual decoded size > typemax(Int32): 2147483648 > 2147483647") decode(d, over_max_cint_zeros)
    end
    @testset "end of block condition 2 and 3" begin
        # decode starts at 12 from end with length 7
        # https://github.com/lz4/lz4/issues/1495#issuecomment-2307679190
        c = UInt8[0x13;0xaa;0x01;0x00;0x50;fill(0xbb,5)]
        @test f(c) == 13
        @test decode(d, c; size_hint=Int64(13)) == [fill(0xaa, 8); fill(0xbb, 5)]

        # match starts starts at 12 from end with length 8
        c = UInt8[0x14;0xaa;0x01;0x00;0x40;fill(0xbb,4)]
        @test_throws LZ4DecodingError("end of block condition 2 violated") f(c)
        @test_throws LZ4DecodingError("end of block condition 2 violated") decode(d, c; size_hint=Int64(13))

        # match starts starts at 11 from end with length 6
        c = UInt8[0x12;0xaa;0x01;0x00;0x50;fill(0xbb,5)]
        @test_throws LZ4DecodingError("end of block condition 3 violated") f(c)
        @test_throws LZ4DecodingError("end of block condition 3 violated") decode(d, c; size_hint=Int64(12))

        # match starts at 9 from end
        c = UInt8[0x10;0xaa;0x01;0x00;0x50;fill(0xbb,5)]
        @test_throws LZ4DecodingError("end of block condition 3 violated") f(c)

        # match starts 11 from end with length 6 but offset 2
        c = UInt8[0x22;0xaa;0xaa;0x02;0x00;0x50;fill(0xbb,5)]
        @test_throws LZ4DecodingError("end of block condition 3 violated") f(c) == 13
        @test_throws LZ4DecodingError("end of block condition 3 violated") decode(d, c; size_hint=Int64(13))
    end
    @testset "errors reading offset" begin
        c = UInt8[0x13;0xaa;0x00;]
        @test_throws LZ4DecodingError("unexpected end of input") f(c)

        c = UInt8[0x13;0xaa;0x00;0x00;]
        @test_throws LZ4DecodingError("zero offset value found") f(c)

        c = UInt8[0x13;0xaa;0x02;0x00;0x50;fill(0xbb,5)]
        @test_throws LZ4DecodingError("offset is before the beginning of the output") f(c)
        @test_throws LZ4DecodingError("offset is before the beginning of the output") decode(d, c; size_hint=Int64(100))

        c = UInt8[0x13;0xaa;0x01;0x00; 0x03;0x02;0x00; 0x50;fill(0xbb,5)]
        @test f(c) == 20
        @test decode(d, c; size_hint=Int64(21)) == [fill(0xaa, 15); fill(0xbb,5);]

        c = UInt8[0x10;0xaa;0x01;0x00; 0x03;0x05;0x00; 0x50;fill(0xbb,5)]
        @test f(c) == 17
        @test decode(d, c; size_hint=Int64(17)) == [fill(0xaa, 12); fill(0xbb,5);]

        c = UInt8[0x10;0xaa;0x01;0x00; 0x03;0x06;0x00; 0x50;fill(0xbb,5)]
        @test_throws LZ4DecodingError("offset is before the beginning of the output") f(c)
        @test_throws LZ4DecodingError("offset is before the beginning of the output") decode(d, c; size_hint=Int64(100))
    end
    @testset "error reading matchlength" begin
        c = UInt8[0x10;0xaa;0x01;0x00; 0x0F;0x01;0x00;]
        @test_throws LZ4DecodingError("unexpected end of input") f(c)
        @test_throws LZ4DecodingError("unexpected end of input") decode(d, c; size_hint=Int64(1000))

        c = UInt8[0x10;0xaa;0x01;0x00; 0x0F;0x01;0x00;0xFF]
        @test_throws LZ4DecodingError("unexpected end of input") f(c)
        @test_throws LZ4DecodingError("unexpected end of input") decode(d, c; size_hint=Int64(1000))
    end
    @testset "exercise offsets" begin
        thing = rand(UInt8, 200)
        u = UInt8[]
        for dist in [0:258; 1000:1030; 2000:1000:33000; 34000:10000:100_000]
            append!(u, thing)
            append!(u, rand(0x00:0x0f, dist))
        end
        c = encode(e, u)
        @test f(c) == length(u)
        @test decode(d, c) == u

        for n in 65536-300:65536
            u = [thing; zeros(UInt8, n); thing]
            c = encode(e, u)
            @test f(c) == length(u)
            @test decode(d, c) == u
        end
    end
end
