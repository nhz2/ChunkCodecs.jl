using Random: Random
using ChunkCodecLibSnappy:
    ChunkCodecLibSnappy,
    SnappyCodec,
    SnappyEncodeOptions,
    SnappyDecodeOptions,
    SnappyDecodingError
using ChunkCodecCore: decode, encode
using ChunkCodecTests: test_codec
using Test: @testset, @test_throws, @test
using Aqua: Aqua

Aqua.test_all(ChunkCodecLibSnappy; persistent_tasks = false)

Random.seed!(1234)

@testset "default" begin
    test_codec(SnappyCodec(), SnappyEncodeOptions(), SnappyDecodeOptions(); trials=100)
end
@testset "errors" begin
    # check SnappyDecodingError prints the correct error message
    @test sprint(Base.showerror, SnappyDecodingError(1)) ==
        "SnappyDecodingError: snappy compressed buffer cannot be decoded, error code: 1"
    # check that a truncated buffer throws a SnappyDecodingError
    u = UInt8[0x00]
    c = encode(SnappyEncodeOptions(), u)
    @test_throws SnappyDecodingError decode(SnappyDecodeOptions(), c[1:end-1])
    @test_throws SnappyDecodingError decode(SnappyDecodeOptions(), UInt8[])
    # check that a buffer with extra data throws a SnappyDecodingError
    @test_throws SnappyDecodingError decode(SnappyDecodeOptions(), [c; 0x00;])
end
