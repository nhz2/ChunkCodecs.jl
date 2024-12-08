using Random: Random
using ChunkCodecCore: ChunkCodecCore, NoopCodec, NoopEncodeOptions, NoopDecodeOptions, DecodedSizeError
using ChunkCodecTests: test_codec
using Aqua: Aqua
using Test: @test, @testset

Aqua.test_all(ChunkCodecCore)

Random.seed!(1234)

@testset "noop codec" begin
    test_codec(NoopCodec(), NoopEncodeOptions(), NoopDecodeOptions(); trials=1000)
end
@testset "errors" begin
    @test sprint(Base.showerror, DecodedSizeError(1, 2)) == "DecodedSizeError: decoded size: 2 is greater than max size: 1"
    @test sprint(Base.showerror, DecodedSizeError(1, nothing)) == "DecodedSizeError: decoded size is greater than max size: 1"
end