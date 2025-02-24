module ChunkCodecCore

export decode, encode

public Codec
public EncodeOptions
public DecodeOptions

public DecodingError
public DecodedSizeError

public decode_options

public decoded_size_range
public encode_bound
public try_encode!

public try_find_decoded_size
public try_decode!

public check_in_range
public check_contiguous

public can_concatenate
public is_thread_safe
public try_resize_decode!

public NoopCodec
public NoopEncodeOptions
public NoopDecodeOptions

public ShuffleCodec
public ShuffleEncodeOptions
public ShuffleDecodeOptions

include("types.jl")
include("errors.jl")
include("interface.jl")
include("noop.jl")
include("shuffle.jl")

end