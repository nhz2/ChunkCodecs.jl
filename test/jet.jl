using JET
using ChunkCodecs
using Test

@testset "$(p)" for p in ChunkCodecs.codec_packages
    JET.test_package(string(p))
end
