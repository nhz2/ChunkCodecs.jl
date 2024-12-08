using Random: Random
using ChunkCodecCBlosc:
    ChunkCodecCBlosc,
    BloscCodec,
    BloscEncodeOptions,
    BloscDecodeOptions,
    BloscDecodingError
using ChunkCodecCore: decode, encode
using ChunkCodecTests: test_codec
using Test: @testset, @test_throws, @test
using Aqua: Aqua

Aqua.test_all(ChunkCodecCBlosc)

Random.seed!(1234)

@testset "default" begin
    test_codec(BloscCodec(), BloscEncodeOptions(), BloscDecodeOptions())
end
@testset "multithreaded" begin
    for i in 1:3
        for j in 1:3
            test_codec(BloscCodec(), BloscEncodeOptions(;numinternalthreads=i), BloscDecodeOptions(;numinternalthreads=j))
        end
    end
end
@testset "typesize" begin
    for i in 1:50
        test_codec(BloscCodec(), BloscEncodeOptions(;typesize=i), BloscDecodeOptions(); trials=10)
    end
end
@testset "invalid encoding options" begin
    @test_throws ArgumentError BloscDecodeOptions(;numinternalthreads=10000)
    @test_throws ArgumentError BloscDecodeOptions(;numinternalthreads=0)
    @test_throws ArgumentError BloscEncodeOptions(;clevel=-1)
    @test_throws ArgumentError BloscEncodeOptions(;clevel=100)
    # typesize can be anything, but out of the range it gets set to 1
    e = BloscEncodeOptions(;typesize=typemax(UInt128))
    @test e.typesize == 1
    e = BloscEncodeOptions(;typesize=0)
    @test e.typesize == 1
    e = BloscEncodeOptions(;typesize=-1)
    @test e.typesize == 1
    e = BloscEncodeOptions(;typesize=ChunkCodecCBlosc.BLOSC_MAX_TYPESIZE)
    @test e.typesize == ChunkCodecCBlosc.BLOSC_MAX_TYPESIZE
    e = BloscEncodeOptions(;typesize=ChunkCodecCBlosc.BLOSC_MAX_TYPESIZE+1)
    @test e.typesize == 1
    @test_throws ArgumentError BloscEncodeOptions(;compressor="")
    @test_throws ArgumentError BloscEncodeOptions(;compressor="asfdgfsdgrwwea")
    @test_throws ArgumentError BloscEncodeOptions(;compressor="blosclz,")
end
@testset "errors" begin
    # check BloscDecodingError prints the correct error message
    @test sprint(Base.showerror, BloscDecodingError(1)) ==
        "BloscDecodingError: blosc compressed buffer cannot be decoded, error code: 1"
    # check that a truncated buffer throws a BloscDecodingError
    u = UInt8[0x00]
    c = encode(BloscEncodeOptions(), u)
    @test_throws BloscDecodingError decode(BloscDecodeOptions(), c[1:end-1])
    @test_throws BloscDecodingError decode(BloscDecodeOptions(), UInt8[0x00])
    # check that a buffer with extra data throws a BloscDecodingError
    @test_throws BloscDecodingError decode(BloscDecodeOptions(), [c; 0x00;])
end