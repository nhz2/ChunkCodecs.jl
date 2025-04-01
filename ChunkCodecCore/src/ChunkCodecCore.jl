module ChunkCodecCore

using Compat: @compat

export decode, encode

@compat public Codec
@compat public EncodeOptions
@compat public DecodeOptions

@compat public DecodingError
@compat public DecodedSizeError

@compat public decode_options

@compat public decoded_size_range
@compat public encode_bound
@compat public try_encode!

@compat public try_find_decoded_size
@compat public try_decode!

@compat public check_in_range
@compat public check_contiguous

@compat public can_concatenate
@compat public is_thread_safe
@compat public try_resize_decode!

@compat public NoopCodec
@compat public NoopEncodeOptions
@compat public NoopDecodeOptions

@compat public ShuffleCodec
@compat public ShuffleEncodeOptions
@compat public ShuffleDecodeOptions

include("types.jl")
include("errors.jl")
include("interface.jl")
include("noop.jl")
include("shuffle.jl")

end
