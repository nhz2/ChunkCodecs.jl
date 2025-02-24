module ChunkCodecs

# reexport ChunkCodecCore
using ChunkCodecCore: ChunkCodecCore, encode, decode
export ChunkCodecCore, encode, decode

codec_packages = [
    :ChunkCodecLibBlosc,
    :ChunkCodecLibBzip2,
    :ChunkCodecLibLz4,
    :ChunkCodecLibZlib,
    :ChunkCodecLibZstd,
]


for p in codec_packages
    @eval import $(p)
    @eval export $(p)
end


end # module ChunkCodecs
