module ChunkCodecLibLz4

using Lz4_jll: liblz4

using ChunkCodecCore:
    Codec,
    EncodeOptions,
    DecodeOptions,
    check_contiguous,
    check_in_range,
    DecodingError
import ChunkCodecCore:
    codec,
    decode_options,
    can_concatenate,
    try_decode!,
    try_resize_decode!,
    try_encode!,
    encode_bound,
    is_thread_safe,
    try_find_decoded_size,
    decoded_size_range,
    decode_options

export LZ4FrameCodec,
    LZ4FrameEncodeOptions,
    LZ4FrameDecodeOptions,
    LZ4BlockCodec,
    LZ4BlockEncodeOptions,
    LZ4BlockDecodeOptions,
    LZ4ZarrCodec,
    LZ4ZarrEncodeOptions,
    LZ4ZarrDecodeOptions,
    # LZ4HDF5Codec,
    # LZ4HDF5EncodeOptions,
    # LZ4HDF5DecodeOptions,
    LZ4DecodingError

public LZ4F_MAX_CLEVEL

# reexport ChunkCodecCore
using ChunkCodecCore: ChunkCodecCore, encode, decode, codec
export ChunkCodecCore, encode, decode, codec


include("liblz4.jl")
include("liblz4frame.jl")

"""
    struct LZ4FrameCodec <: Codec
    LZ4FrameCodec()

lz4 frame compression using liblz4: https://lz4.org/

This is the LZ4 Frame (.lz4) format described in https://github.com/lz4/lz4/blob/v1.10.0/doc/lz4_Frame_format.md

This format is compatible with the `lz4` CLI.

[`LZ4FrameEncodeOptions`](@ref) and [`LZ4FrameDecodeOptions`](@ref)
can be used to set decoding and encoding options.

Encode compresses data as a single frame.
Decoding will succeed even if the decompressed size is unknown.
Decoding accepts concatenated frames 
and will error if there is invalid data appended.

"""
struct LZ4FrameCodec <: Codec
end
decode_options(::LZ4FrameCodec) = LZ4FrameDecodeOptions() # default decode options
can_concatenate(::LZ4FrameCodec) = true

"""
    struct LZ4BlockCodec <: Codec
    LZ4BlockCodec()

lz4 block compression using liblz4: https://lz4.org/

This is the LZ4 Block format described in https://github.com/lz4/lz4/blob/v1.10.0/doc/lz4_Block_format.md

This format has no framing layer and is NOT compatible with the `lz4` CLI.

[`LZ4BlockEncodeOptions`](@ref) and [`LZ4BlockDecodeOptions`](@ref)
can be used to set decoding and encoding options.

Decoding requires the exact compressed size to be known.
"""
struct LZ4BlockCodec <: Codec
end
decode_options(::LZ4BlockCodec) = LZ4BlockDecodeOptions() # default decode options

"""
    struct LZ4ZarrCodec <: Codec
    LZ4ZarrCodec()

lz4 numcodecs style compression using liblz4: https://lz4.org/

This is the [`LZ4BlockCodec`](@ref) format with a 4-byte header containing the
size of the decoded data as a little-endian 32-bit signed integer.

This format is documented in https://numcodecs.readthedocs.io/en/stable/compression/lz4.html

This format is NOT compatible with the `lz4` CLI.

[`LZ4ZarrEncodeOptions`](@ref) and [`LZ4ZarrDecodeOptions`](@ref)
can be used to set decoding and encoding options.

Decoding requires the exact encoded size to be known.
"""
struct LZ4ZarrCodec <: Codec
end
decode_options(::LZ4ZarrCodec) = LZ4ZarrDecodeOptions() # default decode options

include("encode.jl")
include("decode.jl")

end # module ChunkCodecLibLz4
