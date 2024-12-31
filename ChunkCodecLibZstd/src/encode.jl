"""
    struct ZstdEncodeOptions <: EncodeOptions
    ZstdEncodeOptions(::ZstdCodec=ZstdCodec(); kwargs...)

# Keyword Arguments

- `compressionLevel::Integer=0`: Compression level, regular levels are 1-22.
Levels ≥ 20 should be used with caution, as they require more memory.
0 is a special value for `DEFAULT_CLEVEL`.
The lower the level, the faster the compression, but the worse the compression ratio.
The level will be clamped to the range `MIN_CLEVEL` to `MAX_CLEVEL`.
- `checksum::Bool=false`: A 32-bits checksum of content is written at end of frame.
- `advanced_parameters::Vector{Pair{Cint, Cint}}=[]`:
Warning, some parameters can result in encodings that are incompatible with default decoders.
Some parameters are experimental and may change in new versions of libzstd,
so you may need to check `ZSTD_VERSION`. See comments in zstd.h.
Additional parameters are set with `ZSTD_CCtx_setParameter`. These parameters
are set after the compression level, and checksum options are set, 
so they can override those values.
"""
struct ZstdEncodeOptions <: EncodeOptions
    compressionLevel::Cint
    checksum::Bool
    advanced_parameters::Vector{Pair{Cint, Cint}}
end
codec(::ZstdEncodeOptions) = ZstdCodec()
is_thread_safe(::ZstdEncodeOptions) = true

function ZstdEncodeOptions(::ZstdCodec=ZstdCodec();
        compressionLevel::Integer=0,
        checksum::Bool=false,
        advanced_parameters::Vector{Pair{Cint, Cint}}=Pair{Cint, Cint}[],
        kwargs...
    )
    _clamped_compression_level = clamp(compressionLevel, MIN_CLEVEL, MAX_CLEVEL)
    ZstdEncodeOptions(_clamped_compression_level, checksum, advanced_parameters)
end

function decoded_size_range(::ZstdEncodeOptions)
    # prevent overflow of encode_bound
    # like ZSTD_MAX_INPUT_SIZE for Int64
    # From ChunkCodecTests.find_max_decoded_size(ZstdEncodeOptions())
    Int64(0):Int64(1):Int64(0x7F807F807F807F7F)
end

function encode_bound(::ZstdEncodeOptions, src_size::Int64)::Int64
    # ZSTD_COMPRESSBOUND ported to Julia
    # This also works when streaming
    # assuming no extra flushes
    # https://github.com/facebook/zstd/issues/3935
    # From zstd.h
    # #define ZSTD_COMPRESSBOUND(srcSize) (((size_t)(srcSize) >= ZSTD_MAX_INPUT_SIZE) ? 0 : (srcSize) + ((srcSize)>>8) + (((srcSize) < (128<<10)) ? (((128<<10) - (srcSize)) >> 11) /* margin, from 64 to 0 */ : 0)) 
    # /* this formula ensures that bound(A) + bound(B) <= bound(A+B) as long as A and B >= 128 KB */

    # Here we use Int64 instead of size_t
    margin = if src_size < (Int64(128)<<10)
        (((Int64(128)<<10) - src_size) >> 11)
    else 
        Int64(0)
    end::Int64
    clamp(widen(src_size) + widen(src_size>>8 + margin), Int64)
end

function try_encode!(e::ZstdEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    src_size::Int64 = length(src)
    check_in_range(decoded_size_range(e); src_size)
    # create ZSTD_CCtx
    cctx = ccall((:ZSTD_createCCtx, libzstd), Ptr{ZSTD_CCtx}, ())
    if cctx == C_NULL
        throw(OutOfMemoryError())
    end
    try
        # set parameters
        ZSTD_c_compressionLevel = Cint(100)
        ZSTD_c_checksumFlag = Cint(201)
        _set_parameter(cctx, ZSTD_c_compressionLevel, e.compressionLevel)
        if e.checksum
            _set_parameter(cctx, ZSTD_c_checksumFlag, Cint(1))
        end
        for (param, value) in e.advanced_parameters
            _set_parameter(cctx, param, value)
        end
        # do compression
        ret = ccall((:ZSTD_compress2, libzstd), Csize_t,
            (Ptr{ZSTD_CCtx}, Ref{UInt8}, Csize_t, Ref{UInt8}, Csize_t,),
            cctx, dst, length(dst), src, src_size,
        )
        if ZSTD_isError(ret)
            err_code = ZSTD_getErrorCode(ret)
            if err_code == Integer(ZSTD_error_dstSize_tooSmall)
                return nothing
            elseif err_code == Integer(ZSTD_error_memory_allocation)
                throw(OutOfMemoryError())
            else
                error("unexpected libzstd error code $(err_code) from ZSTD_compress2.")
            end
        else
            return Int64(ret)
        end
    finally
        # free ZSTD_CCtx
        ret = ccall((:ZSTD_freeCCtx, libzstd), Csize_t, (Ptr{ZSTD_CCtx},), cctx)
        @assert ret == 0 "ZSTD_freeCCtx should never fail here"
    end
end