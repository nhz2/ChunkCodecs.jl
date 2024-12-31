"""
    struct LZ4FrameEncodeOptions <: EncodeOptions
    LZ4FrameEncodeOptions(::LZ4FrameCodec=LZ4FrameCodec(); kwargs...)

This is the LZ4 Frame (.lz4) format described in https://github.com/lz4/lz4/blob/v1.10.0/doc/lz4_Frame_format.md

# Keyword Arguments

- `compressionLevel::Integer=0`: Compression level, 0: default (fast mode); values > `LZ4F_MAX_CLEVEL` count as `LZ4F_MAX_CLEVEL`; values < 0 trigger fast acceleration
- `blockSizeID::Integer=0`: 0: default (max64KB), 4: max64KB, 5: max256KB, 6: max1MB, 7: max4MB;
The larger the block size, the (slightly) better the compression ratio,
though there are diminishing returns.
Larger blocks also increase memory usage on both compression and decompression sides.
- `blockMode::Bool=false`: false: blockLinked, true: blockIndependent;
Linked blocks sharply reduce inefficiencies when using small blocks, they compress better.
However, some LZ4 decoders are only compatible with independent blocks.
- `contentChecksumFlag::Bool=false`: A 32-bits checksum of content is written at end of frame.
- `contentSize::Bool=false`: Save size of uncompressed content ; false == unknown.
If the content size is zero, it will not be saved, even if this option is true due to a 
limitation in liblz4. Ref: https://github.com/lz4/lz4/issues/775
- `blockChecksumFlag::Bool=false`: each block followed by a checksum of block's compressed data.
- `favorDecSpeed::Bool=false`: if true, parser favors decompression speed vs compression ratio. Only works for high compressionLevel (>= LZ4HC_CLEVEL_OPT_MIN)
"""
struct LZ4FrameEncodeOptions <: EncodeOptions
    compressionLevel::Cint
    blockSizeID::Cint
    blockMode::Bool
    contentChecksumFlag::Bool
    contentSize::Bool
    blockChecksumFlag::Bool
    favorDecSpeed::Bool
end
codec(::LZ4FrameEncodeOptions) = LZ4FrameCodec()
is_thread_safe(::LZ4FrameEncodeOptions) = true

function LZ4FrameEncodeOptions(::LZ4FrameCodec=LZ4FrameCodec();
        compressionLevel::Integer=0,
        blockSizeID::Integer=0,
        blockMode::Bool=false,
        contentChecksumFlag::Bool=false,
        contentSize::Bool=false,
        blockChecksumFlag::Bool=false,
        favorDecSpeed::Bool=false,
        kwargs...
    )
    blockSizeID ∈ (0, 4, 5, 6, 7) || throw(ArgumentError("blockSizeID: $(blockSizeID) must be in (0, 4, 5, 6, 7)"))
    _clamped_compression_level = clamp(compressionLevel, -(LZ4_ACCELERATION_MAX - 1), LZ4F_MAX_CLEVEL)
    LZ4FrameEncodeOptions(_clamped_compression_level, blockSizeID, blockMode, contentChecksumFlag, contentSize, blockChecksumFlag, favorDecSpeed)
end

function _preferences(e::LZ4FrameEncodeOptions)::LZ4F_preferences_t
    LZ4F_preferences_t(
        LZ4F_frameInfo_t(
            LZ4F_blockSizeID_t(e.blockSizeID),
            LZ4F_blockMode_t(e.blockMode),
            LZ4F_contentChecksum_t(e.contentChecksumFlag),
            LZ4F_frame,
            Culonglong(e.contentSize), # https://github.com/lz4/lz4/blob/6cf42afbea04c9ea6a704523aead273715001330/lib/lz4frame.c#L446 auto-correct content size if selected (!=0)
            Cuint(0), # no dictID provided
            LZ4F_blockChecksum_t(e.blockChecksumFlag),
        ),
        e.compressionLevel,
        Cuint(0), # autoFlush, this just gets overwritten anyway at https://github.com/lz4/lz4/blob/6cf42afbea04c9ea6a704523aead273715001330/lib/lz4frame.c#L449
        Cuint(e.favorDecSpeed),
        (Cuint(0), Cuint(0), Cuint(0)), # reserved, must be zero
    )
end

function decoded_size_range(::LZ4FrameEncodeOptions)
    # prevent overflow of encode_bound
    # This should be very conservative
    max_size = if sizeof(Csize_t) == 8
        Int64(2)^47 - Int64(2)
    elseif sizeof(Csize_t) == 4
        Int64(2)^31 - Int64(2)
    else
        @assert false "unreachable"
    end
    Int64(0):Int64(1):max_size
end

function encode_bound(e::LZ4FrameEncodeOptions, src_size::Int64)::Int64
    if src_size < 0
        Int64(-1)
    elseif src_size > last(decoded_size_range(e))
        typemax(Int64)
    else
        LZ4F_compressFrameBound(Csize_t(src_size), _preferences(e))
    end
end

function try_encode!(e::LZ4FrameEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    src_size::Int64 = length(src)
    dst_size::Int64 = length(dst)
    check_in_range(decoded_size_range(e); src_size)
    # LZ4F_compressFrame needs this to hold.
    if dst_size < encode_bound(e, src_size)
        return nothing
    end
    ret = LZ4F_compressFrame(dst, src, _preferences(e))
    if LZ4F_isError(ret)
        error("unexpected LZ4F error: $(LZ4F_getErrorName(ret))")
    else
        Int64(ret)
    end
end

"""
    struct LZ4BlockEncodeOptions <: EncodeOptions
    LZ4BlockEncodeOptions(::LZ4BlockCodec=LZ4BlockCodec(); kwargs...)

This is the LZ4 Block format described in https://github.com/lz4/lz4/blob/v1.10.0/doc/lz4_Block_format.md

This format has no framing layer and is NOT compatible with the `lz4` CLI.

There is also a maximum decoded size of about 2 GB for this implementation.

# Keyword Arguments

- `compressionLevel::Integer=0`: Compression level, 0: default (fast mode); values > `LZ4F_MAX_CLEVEL` count as `LZ4F_MAX_CLEVEL`; values < 0 trigger fast acceleration
"""
struct LZ4BlockEncodeOptions <: EncodeOptions
    compressionLevel::Cint
end
codec(::LZ4BlockEncodeOptions) = LZ4BlockCodec()
is_thread_safe(::LZ4BlockEncodeOptions) = true

function LZ4BlockEncodeOptions(::LZ4BlockCodec=LZ4BlockCodec();
        compressionLevel::Integer=0,
        kwargs...
    )
    _clamped_compression_level = clamp(compressionLevel, -(LZ4_ACCELERATION_MAX - 1), LZ4F_MAX_CLEVEL)
    LZ4BlockEncodeOptions(_clamped_compression_level)
end

decoded_size_range(::LZ4BlockEncodeOptions) = Int64(0):Int64(1):LZ4_MAX_INPUT_SIZE

function encode_bound(e::LZ4BlockEncodeOptions, src_size::Int64)::Int64
    if src_size < 0
        Int64(-1)
    elseif src_size > last(decoded_size_range(e))
        typemax(Int64)
    else
        # from LZ4_COMPRESSBOUND in lz4.h
        src_size + src_size÷Int64(255) + Int64(16)
    end
end

function try_encode!(e::LZ4BlockEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    src_size::Int64 = length(src)
    dst_size::Int64 = length(dst)
    check_in_range(decoded_size_range(e); src_size)
    ret = if e.compressionLevel < LZ4HC_CLEVEL_MIN
        # Fast mode 
        # Convert compressionLevel to acceleration using
        # int const acceleration = (level < 0) ? -level + 1 : 1;
        # from:
        # https://github.com/lz4/lz4/blob/6cf42afbea04c9ea6a704523aead273715001330/lib/lz4frame.c#L913
        acceleration = if e.compressionLevel < 0
            -e.compressionLevel + Cint(1)
        else
            Cint(1)
        end
        ccall(
            (:LZ4_compress_fast, liblz4), Cint,
            (Ptr{UInt8}, Ptr{UInt8}, Cint, Cint, Cint),
            src, dst, src_size, clamp(dst_size, Cint), acceleration
        )
    else
        # HC mode
        # compressionLevel is normal
        ccall(
            (:LZ4_compress_HC, liblz4), Cint,
            (Ptr{UInt8}, Ptr{UInt8}, Cint, Cint, Cint),
            src, dst, src_size, clamp(dst_size, Cint), e.compressionLevel
        )
    end
    if iszero(ret)
        nothing
    else
        Int64(ret)
    end
end

"""
    struct LZ4ZarrEncodeOptions <: EncodeOptions
    LZ4ZarrEncodeOptions(::LZ4ZarrCodec=LZ4ZarrCodec(); kwargs...)

lz4 numcodecs style compression using liblz4: https://lz4.org/

This is the LZ4 Zarr format described in https://numcodecs.readthedocs.io/en/stable/compression/lz4.html

# Keyword Arguments

- `compressionLevel::Integer=0`: Compression level, 0: default (fast mode); values > `LZ4F_MAX_CLEVEL` count as `LZ4F_MAX_CLEVEL`; values < 0 trigger fast acceleration
"""
struct LZ4ZarrEncodeOptions <: EncodeOptions
    block_options::LZ4BlockEncodeOptions
end
codec(::LZ4ZarrEncodeOptions) = LZ4ZarrCodec()
is_thread_safe(::LZ4ZarrEncodeOptions) = true

function LZ4ZarrEncodeOptions(::LZ4ZarrCodec=LZ4ZarrCodec();
        compressionLevel::Integer=0,
        kwargs...
    )
    LZ4ZarrEncodeOptions(LZ4BlockEncodeOptions(;compressionLevel))
end

decoded_size_range(e::LZ4ZarrEncodeOptions) = Int64(0):Int64(1):min(last(decoded_size_range(e.block_options)), Int64(typemax(Int32)))

function encode_bound(e::LZ4ZarrEncodeOptions, src_size::Int64)::Int64
    clamp(widen(encode_bound(e.block_options, src_size)) + widen(Int64(4)), Int64)
end

function try_encode!(e::LZ4ZarrEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    src_size::Int64 = length(src)
    dst_size::Int64 = length(dst)
    check_in_range(decoded_size_range(e); src_size) # this errors if src_size can't fit in 4 bytes
    @assert src_size ≤ typemax(Int32)
    if dst_size < 5
        return nothing
    end
    for i in 0:3
        dst[begin+i] = src_size>>>(i*8) & 0xFF
    end
    ret = try_encode!(e.block_options, @view(dst[begin+4:end]) , src)
    if isnothing(ret)
        return nothing
    else
        return ret + Int64(4)
    end
end
