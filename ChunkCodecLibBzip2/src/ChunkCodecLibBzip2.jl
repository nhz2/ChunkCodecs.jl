module ChunkCodecLibBzip2

using Bzip2_jll: libbzip2

using ChunkCodecCore:
    Codec,
    EncodeOptions,
    DecodeOptions,
    check_in_range,
    check_contiguous,
    DecodingError
import ChunkCodecCore:
    codec,
    decode_options,
    can_concatenate,
    try_decode!,
    try_resize_decode!,
    try_encode!,
    encoded_bound,
    is_thread_safe,
    try_find_decoded_size,
    decoded_size_range

export BZ2Codec,
    BZ2EncodeOptions,
    BZ2DecodeOptions,
    BZ2DecodingError

# reexport ChunkCodecCore
using ChunkCodecCore: ChunkCodecCore, encode, decode, codec
export ChunkCodecCore, encode, decode, codec


include("libbzip2.jl")

"""
    struct BZ2Codec <: Codec
    BZ2Codec()

bzip2 compression using libbzip2: https://sourceware.org/bzip2/

Like the command line tool `bunzip2`, decoding accepts concatenated compressed data and returns the decompressed data concatenated.
Unlike `bunzip2`, decoding will error if the compressed stream has invalid data appended to it.

[`BZ2EncodeOptions`](@ref) and [`BZ2DecodeOptions`](@ref)
can be used to set decoding and encoding options.
"""
struct BZ2Codec <: Codec
end
decode_options(::BZ2Codec) = BZ2DecodeOptions() # default decode options

can_concatenate(::BZ2Codec) = true

include("encode.jl")
include("decode.jl")

end # module ChunkCodecLibBzip2
