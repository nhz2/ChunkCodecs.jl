using Random: Random
using ChunkCodecTests
using ChunkCodecCore: ChunkCodecCore, NoopCodec, NoopEncodeOptions, NoopDecodeOptions
using Aqua: Aqua
using Test: @test, @testset

Aqua.test_all(ChunkCodecTests)

Random.seed!(1234)

@testset "noop codec" begin
    test_codec(NoopCodec(), NoopEncodeOptions(), NoopDecodeOptions(); trials=100)
end
