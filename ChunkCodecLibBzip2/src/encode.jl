"""
    struct BZ2EncodeOptions <: EncodeOptions
    BZ2EncodeOptions(::BZ2Codec=BZ2Codec(); kwargs...)

bzip2 compression using libbzip2: https://sourceware.org/bzip2/

# Keyword Arguments

- `blockSize100k::Integer=9`: Specifies the block size to be used for compression.
It should be a value between 1 and 9 inclusive, and the actual block size used
is 100000 x this figure. The default 9 gives the best compression but takes most memory.
"""
struct BZ2EncodeOptions <: EncodeOptions
    blockSize100k::Cint
end
codec(::BZ2EncodeOptions) = BZ2Codec()
is_thread_safe(::BZ2EncodeOptions) = true

function BZ2EncodeOptions(::BZ2Codec=BZ2Codec();
        blockSize100k::Integer=9,
        kwargs...
    )
    check_in_range(1:9; blockSize100k)
    BZ2EncodeOptions(
        blockSize100k,
    )
end

function decoded_size_range(::BZ2EncodeOptions)
    # prevent overflow of encoded_bound
    Int64(0):Int64(1):Int64(0x7E07_e07e_07e0_7bb8)
end

# According to the docs https://sourceware.org/bzip2/manual/manual.html:
# "To guarantee that the compressed data will fit in its buffer,
# allocate an output buffer of size 1% larger than the uncompressed data,
# plus six hundred extra bytes."
encoded_bound(::BZ2EncodeOptions, src_size::Int64)::Int64 = Base.checked_add(src_size, src_size>>6 + Int64(601))

function try_encode!(e::BZ2EncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    src_size::Int64 = length(src)
    dst_size::Int64 = length(dst)
    check_in_range(decoded_size_range(e); src_size)
    if iszero(dst_size)
        return nothing
    end
    stream = BZStream()
    BZ2_bzCompressInit(stream, e.blockSize100k)
    try
        # BZ2_bzCompress loop
        cconv_src = Base.cconvert(Ptr{UInt8}, src)
        cconv_dst = Base.cconvert(Ptr{UInt8}, dst)
        GC.@preserve cconv_src cconv_dst begin
            src_p = Base.unsafe_convert(Ptr{UInt8}, cconv_src)
            dst_p = Base.unsafe_convert(Ptr{UInt8}, cconv_dst)
            stream.next_in = src_p
            stream.next_out = dst_p
            src_left::Int64 = src_size
            dst_left::Int64 = dst_size
            while true
                start_avail_in = min(clamp(src_left, Cuint), Cuint(2^26))
                start_avail_out = clamp(dst_left, Cuint)
                stream.avail_in = start_avail_in
                stream.avail_out = start_avail_out
                @assert !iszero(stream.avail_out)
                action = if stream.avail_in == src_left
                    BZ_FINISH
                else
                    BZ_RUN
                end
                ret = BZ2_bzCompress(stream, action)
                @assert stream.avail_in ≤ start_avail_in
                @assert stream.avail_out ≤ start_avail_out
                # there must be progress
                @assert stream.avail_in < start_avail_in || stream.avail_out < start_avail_out
                src_left -= start_avail_in - stream.avail_in
                dst_left -= start_avail_out - stream.avail_out
                @assert src_left ∈ 0:src_size
                @assert dst_left ∈ 0:dst_size
                @assert stream.next_in == src_p + (src_size - src_left)
                @assert stream.next_out == dst_p + (dst_size - dst_left)
                if ret == BZ_STREAM_END
                    # yay done just return compressed size
                    @assert dst_left ∈ 0:dst_size
                    @assert iszero(src_left)
                    return dst_size - dst_left
                end
                if iszero(dst_left)
                    # no more space, but not BZ_STREAM_END
                    return nothing
                end
                if action == BZ_RUN
                    @assert ret == BZ_RUN_OK
                else
                    @assert ret == BZ_FINISH_OK
                end
            end
        end
    finally
        BZ2_bzCompressEnd(stream)
    end
end