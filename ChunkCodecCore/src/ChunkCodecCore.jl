module ChunkCodecCore

export decode, encode, codec

public Codec
public EncodeOptions
public DecodeOptions
public DecodingError
public DecodedSizeError
public can_concatenate
public is_thread_safe
public decode_options
public decoded_size_range
public encoded_bound
public try_encode!
public check_in_range
public check_contiguous
public try_resize_decode!
public try_decode!
public try_find_decoded_size

include("types.jl")
include("errors.jl")
include("interface.jl")
include("noop.jl")

end