using ChunkCodecCore: encode_bound, decoded_size_range, encode, decode
using ChunkCodecLibLz4
using ChunkCodecTests: test_codec
using Test: @testset, @test_throws, @test

@testset "default" begin
    test_codec(LZ4FrameCodec(), LZ4FrameEncodeOptions(), LZ4FrameDecodeOptions(); trials=100)
end
@testset "compressionLevel options" begin
    # Compression level is clamped
    for favorDecSpeed in (false,true)
        for compressionLevel in [typemin(Int128); -30:13; typemax(Int128)]
            test_codec(
                LZ4FrameCodec(),
                LZ4FrameEncodeOptions(; compressionLevel, favorDecSpeed),
                LZ4FrameDecodeOptions();
                trials=3,
            )
        end
    end
end
@testset "blockSizeID and blockMode options" begin
    @test_throws ArgumentError LZ4FrameEncodeOptions(; blockSizeID=1000)
    @test_throws ArgumentError LZ4FrameEncodeOptions(; blockSizeID=3)
    @test_throws ArgumentError LZ4FrameEncodeOptions(; blockSizeID=-1)
    for blockMode in (false, true)
        for blockSizeID in (0, 4, 5, 6, 7)
            local e = LZ4FrameEncodeOptions(;blockSizeID, blockMode)
            local d = LZ4FrameDecodeOptions()
            test_codec(LZ4FrameCodec(), e, d; trials=3)
            # Encode and decode large amounts to really test this
            local u = rand(UInt8, 2^26)
            local c = encode(e, u)
            @test decode(d, c) == u
            local u = ones(UInt8, 2^26)
            local c = encode(e, u)
            @test decode(d, c) == u
        end
    end
end
@testset "other options" begin
    for contentChecksumFlag in (false, true), contentSize in (false, true), blockChecksumFlag in (false, true)
        local e = LZ4FrameEncodeOptions(;contentChecksumFlag, contentSize, blockChecksumFlag)
        local d = LZ4FrameDecodeOptions()
        test_codec(LZ4FrameCodec(), e, d; trials=3)
        # Encode and decode large amounts to really test this
        local u = rand(UInt8, 2^26)
        local c = encode(e, u)
        @test decode(d, c) == u
        local u = ones(UInt8, 2^26)
        local c = encode(e, u)
        @test decode(d, c) == u
    end
end
@testset "unexpected eof" begin
    e = LZ4FrameEncodeOptions()
    d = LZ4FrameDecodeOptions()
    u = [0x00, 0x01, 0x02]
    c = encode(e, u)
    @test decode(d, c) == u
    for i in 1:length(c)
        @test_throws LZ4DecodingError decode(d, c[1:i-1])
    end
    @test_throws LZ4DecodingError decode(d, u)
    c[2] = 0x00
    @test_throws LZ4DecodingError decode(d, c)
    @test_throws LZ4DecodingError decode(d, [encode(e, u); c])
    @test_throws LZ4DecodingError decode(d, [encode(e, u); 0x00])
    e = LZ4FrameEncodeOptions(;contentChecksumFlag=true)
    c = encode(e, u)
    c[end] ⊻= 0xFF
    # This fails checksum
    @test_throws LZ4DecodingError decode(d, c)
end
@testset "Skippable Frames" begin
    e = LZ4FrameEncodeOptions()
    d = LZ4FrameDecodeOptions()
    u = [0x00, 0x01, 0x02]
    c = [encode(e, u); 0x50; 0x2A; 0x4D; 0x18; 0x00; 0x00; 0x00; 0x00]
    @test decode(d, c) == u
    @test_throws LZ4DecodingError decode(d, c[1:end-1])
    c = [encode(e, u); 0x50; 0x2A; 0x4D; 0x18; 0x01; 0x00; 0x00; 0x00; 0x42]
    @test decode(d, c) == u
    @test_throws LZ4DecodingError decode(d, c[1:end-1])
    @test decode(d, [0x50; 0x2A; 0x4D; 0x18; 0x00; 0x00; 0x00; 0x00]) == UInt8[]
end
