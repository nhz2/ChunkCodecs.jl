using Random: Random
using ChunkCodecCore: encoded_bound, decoded_size_range, encode, decode
using ChunkCodecLibBzip2:
    ChunkCodecLibBzip2,
    BZ2Codec,
    BZ2EncodeOptions,
    BZ2DecodeOptions,
    BZ2DecodingError
using ChunkCodecTests: test_codec
using Test: @testset, @test_throws, @test
using Aqua: Aqua

Aqua.test_all(ChunkCodecLibBzip2)

Random.seed!(1234)
@testset "encode_bound" begin
    local a = last(decoded_size_range(BZ2EncodeOptions()))
    @test encoded_bound(BZ2EncodeOptions(), a) == typemax(Int64)
end
@testset "default" begin
    test_codec(BZ2Codec(), BZ2EncodeOptions(), BZ2DecodeOptions(); trials=50)
end
@testset "blockSize100k options" begin
    @test_throws ArgumentError BZ2EncodeOptions(; blockSize100k=0)
    @test_throws ArgumentError BZ2EncodeOptions(; blockSize100k=10)
    @test_throws ArgumentError BZ2EncodeOptions(; blockSize100k=-1)
    for i in 1:9
        test_codec(BZ2Codec(), BZ2EncodeOptions(; blockSize100k=i), BZ2DecodeOptions(); trials=5)
    end
end
@testset "unexpected eof" begin
    e = BZ2EncodeOptions()
    d = BZ2DecodeOptions()
    u = [0x00, 0x01, 0x02]
    c = encode(e, u)
    @test decode(d, c) == u
    for i in 1:length(c)
        @test_throws BZ2DecodingError(ChunkCodecLibBzip2.BZ_UNEXPECTED_EOF) decode(d, c[1:i-1])
    end
    @test_throws BZ2DecodingError decode(d, u)
    c[end] = 0x00
    @test_throws BZ2DecodingError decode(d, c)
    @test_throws BZ2DecodingError decode(d, [encode(e, u); c])
    @test_throws BZ2DecodingError decode(d, [encode(e, u); 0x00])
end
@testset "errors" begin
    @test sprint(Base.showerror, BZ2DecodingError(ChunkCodecLibBzip2.BZ_UNEXPECTED_EOF)) ==
        "BZ2DecodingError: BZ_UNEXPECTED_EOF: the compressed stream may be truncated"
    @test sprint(Base.showerror, BZ2DecodingError(ChunkCodecLibBzip2.BZ_DATA_ERROR)) ==
        "BZ2DecodingError: BZ_DATA_ERROR: a data integrity error is detected in the compressed stream"
    @test sprint(Base.showerror, BZ2DecodingError(ChunkCodecLibBzip2.BZ_DATA_ERROR_MAGIC)) ==
        "BZ2DecodingError: BZ_DATA_ERROR_MAGIC: the compressed stream doesn't begin with the right magic bytes"
    @test sprint(Base.showerror, BZ2DecodingError(-100)) ==
        "BZ2DecodingError: unknown bzip2 error code: -100"
end
