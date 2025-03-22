module ChunkCodecLibSnappy

using snappy_jll: libsnappy

using ChunkCodecCore:
    Codec,
    EncodeOptions,
    DecodeOptions,
    check_in_range,
    check_contiguous,
    DecodingError
import ChunkCodecCore:
    decode_options,
    try_decode!,
    try_encode!,
    encode_bound,
    try_find_decoded_size,
    decoded_size_range

export SnappyCodec,
    SnappyEncodeOptions,
    SnappyDecodeOptions,
    SnappyDecodingError

# reexport ChunkCodecCore
using ChunkCodecCore: ChunkCodecCore, encode, decode
export ChunkCodecCore, encode, decode

include("libsnappy.jl")

"""
    struct SnappyCodec <: Codec
    SnappyCodec()

Snappy compression using the snappy C++ library: https://github.com/google/snappy

There is currently a maximum decoded size of about 1.8 GB.

This may change if https://github.com/google/snappy/issues/201 is resolved.

See also [`SnappyEncodeOptions`](@ref) and [`SnappyDecodeOptions`](@ref)
"""
struct SnappyCodec <: Codec end
decode_options(::SnappyCodec) = SnappyDecodeOptions()

include("encode.jl")
include("decode.jl")

end # module ChunkCodecLibSnappy
