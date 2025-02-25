# This file contains tests that require a large amount of memory (at least 15 GB)
# and take a long time to run. The tests are designed to check the 
# compression and decompression functionality of the ChunkCodecLibBzip2 package 
# with very large inputs. These tests are not run with CI

using ChunkCodecLibBzip2:
    ChunkCodecLibBzip2,
    BZ2Codec,
    BZ2EncodeOptions,
    encode,
    decode
using Test: @testset, @test
using Random

@testset "Big Memory Tests" begin
    Sys.WORD_SIZE == 64 || error("tests require 64 bit word size")
    let
        local e = BZ2EncodeOptions(;blockSize100k=1)
        local n = 2^32-34520475+275580
        local u = rand(Xoshiro(1234), UInt8, n)
        local c = encode(e, u)
        local u2 = decode(e.codec, c; size_hint=n, max_size=n)
        c = nothing
        are_equal = u == u2
        @test are_equal
    end
    @info "compressing zeros"
    for n in (2^32 - 1, 2^32, 2^32 +1, 2^33)
        @info "compressing"
        local c = encode(BZ2EncodeOptions(), zeros(UInt8, n))
        @info "decompressing"
        local u = decode(BZ2Codec(), c; size_hint=n)
        c = nothing
        all_zero = all(iszero, u)
        len_n = length(u) == n
        @test all_zero && len_n
    end

    @info "compressing random"
    for n in (2^32 - 1, 2^32, 2^32 +1)
        local u = rand(UInt8, n)
        @info "compressing"
        local c = encode(BZ2EncodeOptions(), u)
        @info "decompressing"
        local u2 = decode(BZ2Codec(), c)
        c = nothing
        are_equal = u == u2
        @test are_equal
    end

    @info "decompressing huge concatenation"
    uncompressed = rand(UInt8, 2^20)
    @info "compressing"
    compressed = encode(BZ2EncodeOptions(), uncompressed)
    total_compressed = UInt8[]
    sizehint!(total_compressed, length(compressed)*2^12)
    total_uncompressed = UInt8[]
    sizehint!(total_uncompressed, length(uncompressed)*2^12)
    for i in 1:2^12
        append!(total_uncompressed, uncompressed)
        append!(total_compressed, compressed)
    end
    @test length(total_compressed) > 2^32
    @info "decompressing"
    @test total_uncompressed == decode(BZ2Codec(), total_compressed; size_hint=length(total_uncompressed))
end
