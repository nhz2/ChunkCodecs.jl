module ChunkCodecLibZstd

using Zstd_jll: libzstd

using ChunkCodecCore:
    Codec,
    EncodeOptions,
    DecodeOptions,
    check_contiguous,
    check_in_range,
    DecodingError

import ChunkCodecCore:
    codec,
    can_concatenate,
    try_decode!,
    try_encode!,
    encoded_bound,
    is_thread_safe,
    try_find_decoded_size,
    decoded_size_range,
    decode_options

export ZstdCodec,
    ZstdEncodeOptions,
    ZstdDecodeOptions,
    ZstdDecodingError

public MIN_CLEVEL,
    MAX_CLEVEL,
    DEFAULT_CLEVEL,
    ZSTD_VERSION,
    ZSTD_isError,
    ZSTD_bounds,
    ZSTD_cParam_getBounds

# reexport ChunkCodecCore
using ChunkCodecCore: ChunkCodecCore, encode, decode, codec
export ChunkCodecCore, encode, decode, codec


include("libzstd.jl")

"""
    struct ZstdCodec <: Codec
    ZstdCodec()

Zstandard compression using libzstd: www.zstd.net

Zstandard's format is documented in [RFC8878](https://datatracker.ietf.org/doc/html/rfc8878)

Like libzstd's simple API, encode compresses data as a single frame with saved
decompressed size. Decoding will succeed even if the decompressed size is unknown.
Also like libzstd's simple API, decoding accepts concatenated frames 
and will error if there is invalid data appended.

[`ZlibEncodeOptions`](@ref) and [`ZlibDecodeOptions`](@ref)
can be used to set decoding and encoding options.
"""
struct ZstdCodec <: Codec
end
decode_options(::ZstdCodec) = ZstdDecodeOptions() # default decode options
can_concatenate(::ZstdCodec) = true

include("encode.jl")
include("decode.jl")

end # module ChunkCodecLibZstd
