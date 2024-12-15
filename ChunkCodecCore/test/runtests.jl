using Random: Random
using ChunkCodecCore: ChunkCodecCore, NoopCodec, NoopEncodeOptions, NoopDecodeOptions, DecodedSizeError, decode
using ChunkCodecTests: test_codec
using Aqua: Aqua
using Test: @test, @testset, @test_throws

Aqua.test_all(ChunkCodecCore)

Random.seed!(1234)

@testset "noop codec" begin
    test_codec(NoopCodec(), NoopEncodeOptions(), NoopDecodeOptions(); trials=100)
end
@testset "errors" begin
    @test sprint(Base.showerror, DecodedSizeError(1, 2)) == "DecodedSizeError: decoded size: 2 is greater than max size: 1"
    @test sprint(Base.showerror, DecodedSizeError(1, nothing)) == "DecodedSizeError: decoded size is greater than max size: 1"
end
@testset "check helpers" begin
    @test_throws Exception ChunkCodecCore.check_contiguous(@view(zeros(UInt8, 8)[1:2:end]))
    @test_throws Exception ChunkCodecCore.check_contiguous(0x00:0xFF)
    @test isnothing(ChunkCodecCore.check_contiguous(Memory{UInt8}(undef, 3)))
    @test isnothing(ChunkCodecCore.check_contiguous(Vector{UInt8}(undef, 3)))
    @test isnothing(ChunkCodecCore.check_contiguous(@view(zeros(UInt8, 8)[1:1:end])))
    @test_throws ArgumentError ChunkCodecCore.check_in_range(1:6; x=0)
    @test_throws ArgumentError ChunkCodecCore.check_in_range(1:6; x=7)
    @test isnothing(ChunkCodecCore.check_in_range(1:6; x=6))
    @test isnothing(ChunkCodecCore.check_in_range(1:6; x=1))
end

# version of NoopDecodeOptions that returns unknown try_find_decoded_size
struct TestDecodeOptions <: ChunkCodecCore.DecodeOptions
    function TestDecodeOptions(::NoopCodec=NoopCodec();
            kwargs...
        )
        new()
    end
end
ChunkCodecCore.codec(::TestDecodeOptions) = NoopCodec()
ChunkCodecCore.try_find_decoded_size(::TestDecodeOptions, src::AbstractVector{UInt8}) = nothing
function ChunkCodecCore.try_decode!(::TestDecodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    dst_size::Int64 = length(dst)
    src_size::Int64 = length(src)
    if dst_size < src_size
        nothing
    else
        copyto!(dst, src)
        src_size
    end
end

@testset "decode with unknown decoded size" begin
    test_codec(NoopCodec(), NoopEncodeOptions(), TestDecodeOptions(); trials=100)
end

@testset "decode size_hint and resizing" begin
    d = TestDecodeOptions()
    @test decode(d, ones(UInt8, 100); size_hint=200) == ones(UInt8, 100)
    @test decode(d, ones(UInt8, 100); size_hint=99) == ones(UInt8, 100)
    @test decode(d, ones(UInt8, 100); size_hint=99, max_size=100) == ones(UInt8, 100)
    @test_throws DecodedSizeError decode(d, ones(UInt8, 100); size_hint=200, max_size=99)
end