"""
    struct SnappyEncodeOptions <: EncodeOptions
    SnappyEncodeOptions(; kwargs...)

Snappy compression using the snappy C++ library: https://github.com/google/snappy

There is currently a maximum decoded size of about 1.8 GB.

This may change if https://github.com/google/snappy/issues/201 is resolved.

# Keyword Arguments

- `codec::SnappyCodec=SnappyCodec()`
"""
struct SnappyEncodeOptions <: EncodeOptions
    codec::SnappyCodec
end
function SnappyEncodeOptions(;
        codec::SnappyCodec=SnappyCodec(),
        kwargs...
    )
    SnappyEncodeOptions(
        codec,
    )
end

# This prevents the encoded size from being larger than typemax(Int32)
# This is needed to prevent overflows in the C++ code.
# TODO adjust based on what happens with https://github.com/google/snappy/issues/201
decoded_size_range(::SnappyEncodeOptions) = Int64(0):Int64(1):Int64(1840700242)

function encode_bound(e::SnappyEncodeOptions, src_size::Int64)::Int64
    if src_size > last(decoded_size_range(e))
        typemax(Int64)
    else
        # from https://github.com/google/snappy/blob/32ded457c0b1fe78ceb8397632c416568d6714a0/snappy.cc#L218C10-L218C46
        Int64(32) + src_size + src_size ÷ 6
    end
end

function try_encode!(e::SnappyEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    src_size::Int64 = length(src)
    dst_size::Int64 = length(dst)
    check_in_range(decoded_size_range(e); src_size)
    ebound = encode_bound(e, src_size)
    if dst_size < ebound
        return nothing
    end
    compressed_length = Ref(Csize_t(ebound))
    status = ccall((:snappy_compress, libsnappy), Cint,
        (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Ref{Csize_t}),
        src, src_size, dst, compressed_length
    )
    if status == SNAPPY_OK
        Int64(compressed_length[])
    else
        error("Unknown snappy error: $(status)")
    end
end
