# This file contains tests that require a large amount of memory (at least 15 GB)
# and take a long time to run. The tests are designed to check the 
# compression and decompression functionality of the ChunkCodecLibLz4 package 
# with very large inputs. These tests are not run with CI


using ChunkCodecLibLz4:
    ChunkCodecLibLz4,
    LZ4BlockCodec,
    LZ4BlockEncodeOptions,
    LZ4NumcodecsCodec,
    LZ4NumcodecsEncodeOptions,
    encode,
    decode,
    LZ4DecodingError
using ChunkCodecCore:
    decoded_size_range
using Test: @testset, @test, @test_throws
using Random

@testset "Big Memory Tests" begin
    Sys.WORD_SIZE == 64 || error("tests require 64 bit word size")
    @testset "try to decode over typemax(Int32) bytes" begin
        @test_throws LZ4DecodingError("encoded size is larger than `typemax(Int32)`") decode(LZ4BlockCodec(), zeros(UInt8, 2^31))
        @test_throws LZ4DecodingError("encoded size is larger than `typemax(Int32) + 4`") decode(LZ4NumcodecsCodec(), zeros(UInt8, 2^31+4))
        let
            # Design an input that is exactly length `typemax(Int32)`
            # [0xF0; fill(0xFF, N); Y; fill(junk, M);]
            # L = 2 + N + M
            # M = 15 + 255*N + Y
            # L = 17 + 256*N + Y
            # N = 8388607, Y = 238, L = typemax(Int32)
            local N = 8388607
            local Y = 238
            local M = 15 + 255*N + Y
            local max_encoded = [0xF0; fill(0xFF, N); UInt8(Y); fill(0x42, M);]
            @test decode(LZ4BlockCodec(), max_encoded) == fill(0x42, M)
            @test decode(LZ4NumcodecsCodec(), [reinterpret(NTuple{4, UInt8}, htol(Int32(M)))...; max_encoded]) == fill(0x42, M)
        end
    end
    @testset "max decoded size" begin
        let
            local max_cint_zeros = UInt8[0x1F;0x00;0x01;0x00;fill(0xFF,8421504);0x66;0x50;fill(0x00,5)]
            local m = last(decoded_size_range(LZ4BlockEncodeOptions()))
            local input = zeros(UInt8, m)
            for i in m:-1:m-16
                local c = encode(LZ4BlockEncodeOptions(), @view(input[1:i]))
                @test ChunkCodecLibLz4.dry_run_block_decode(c) == i
            end
            local out = decode(LZ4BlockCodec(), max_cint_zeros)
            @test all(iszero, out)
            @test length(out) == typemax(Cint)
            
            input = rand(UInt8, m)
            local c = encode(LZ4BlockEncodeOptions(), input)
            @test ChunkCodecLibLz4.dry_run_block_decode(c) == m
            @test decode(LZ4BlockCodec(), c) == input

            c = encode(LZ4NumcodecsEncodeOptions(), input)
            @test decode(LZ4NumcodecsCodec(), c) == input
            c = UInt8[0xFF;0xFF;0xFF;0x7F; 0x1F;0x00;0x01;0x00;fill(0xFF,8421504);0x66;0x50;fill(0x00,5)]
            out = decode(LZ4NumcodecsCodec(), c)
            @test all(iszero, out)
            @test length(out) == typemax(Cint)
        end
    end
end
