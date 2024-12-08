"""
    ZstdDecodingError(x)

Error for data that cannot be decoded.
"""
struct ZstdDecodingError <: DecodingError
    x::Union{Symbol, Csize_t}
end

function Base.showerror(io::IO, err::ZstdDecodingError)
    print(io, "ZstdDecodingError: ")
    if err.x isa Symbol
        print(io, err.x)
    else
        print(io, ZSTD_getErrorName(err.x))
    end
    nothing
end

"""
    struct ZstdDecodeOptions <: DecodeOptions
    ZstdDecodeOptions(::ZstdCodec=ZstdCodec(); kwargs...)

# Keyword Arguments

- `advanced_parameters::Vector{Pair{Cint, Cint}}=[]`:
Warning, some parameters are experimental and may change in new versions of libzstd,
so you may need to check `ZSTD_VERSION`. See comments in zstd.h.
Additional parameters are set with `ZSTD_DCtx_setParameter`.
"""
struct ZstdDecodeOptions <: DecodeOptions
    advanced_parameters::Vector{Pair{Cint, Cint}}
end
function ZstdDecodeOptions(::ZstdCodec=ZstdCodec(); 
        advanced_parameters::Vector{Pair{Cint, Cint}}=Pair{Cint, Cint}[],
        kwargs...
    )
    ZstdDecodeOptions(advanced_parameters)
end
codec(::ZstdDecodeOptions) = ZstdCodec()
is_thread_safe(::ZstdDecodeOptions) = true

# find_decompressed_size is modified from CodecZstd.jl
# https://github.com/JuliaIO/CodecZstd.jl/blob/2f7d084b8b157d83ed85e9d15105f0a708038e45/src/libzstd.jl#L157C1-L215C4
# From mkitti's PR https://github.com/JuliaIO/CodecZstd.jl/pull/63
function try_find_decoded_size(::ZstdDecodeOptions, src::AbstractVector{UInt8})::Union{Nothing, Int64}
    check_contiguous(src)
    srcSize::Int64 = length(src)
    frameOffset::Int64 = 0
    decompressedSize::Int64 = 0
    while frameOffset < srcSize
        remainingSize = srcSize - frameOffset
        # Obtain the decompressed frame content size of the next frame, accumulate
        frameContentSize = ccall(
            (:ZSTD_getFrameContentSize, libzstd), Culonglong,
            (Ref{UInt8}, Csize_t),
            Ref(src, firstindex(src) + frameOffset), remainingSize,
        )
        if frameContentSize == ZSTD_CONTENTSIZE_UNKNOWN
            return nothing
        end
        if frameContentSize > typemax(Int64) # also handles ZSTD_CONTENTSIZE_ERROR
            throw(ZstdDecodingError(:decoded_size_error))
        end
        decompressedSize, overflow = Base.add_with_overflow(decompressedSize, frameContentSize%Int64)
        if overflow
            throw(ZstdDecodingError(:decoded_size_overflow))
        end
        # Advance the offset forward by the size of the compressed frame
        # this is required if there are more than on frame
        ret = ccall(
            (:ZSTD_findFrameCompressedSize, libzstd), Csize_t,
            (Ref{UInt8}, Csize_t),
            Ref(src, firstindex(src) + frameOffset), remainingSize,
        )
        if ZSTD_isError(ret)
            err_code = ZSTD_getErrorCode(ret)
            if err_code == Integer(ZSTD_error_memory_allocation)
                throw(OutOfMemoryError())
            else
                throw(ZstdDecodingError(ret))
            end
        end
        @assert ret ∈ 1:remainingSize
        frameOffset += Int64(ret)
    end
    @assert frameOffset == srcSize
    return decompressedSize
end

function try_decode!(d::ZstdDecodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    if isempty(src)
        throw(ZstdDecodingError(:src_empty))
    end
    # create ZSTD_CCtx
    dctx = ccall((:ZSTD_createDCtx, libzstd), Ptr{ZSTD_DCtx}, ())
    if dctx == C_NULL
        throw(OutOfMemoryError())
    end
    try
        # set parameters
        for (param, value) in d.advanced_parameters
            _set_parameter(dctx, param, value)
        end
        # do decompression
        ret = ccall((:ZSTD_decompressDCtx, libzstd), Csize_t,
            (Ptr{ZSTD_DCtx}, Ref{UInt8}, Csize_t, Ref{UInt8}, Csize_t,),
            dctx, dst, length(dst), src, length(src),
        )
        if ZSTD_isError(ret)
            err_code = ZSTD_getErrorCode(ret)
            if err_code == Integer(ZSTD_error_dstSize_tooSmall)
                return nothing
            elseif err_code == Integer(ZSTD_error_memory_allocation)
                throw(OutOfMemoryError())
            else
                throw(ZstdDecodingError(ret))
            end
        else
            @assert ret ∈ 0:length(dst)
            return Int64(ret)
        end
    finally
        # free ZSTD_DCtx
        ret = ccall((:ZSTD_freeDCtx, libzstd), Csize_t, (Ptr{ZSTD_DCtx},), dctx)
        @assert ret == 0 "ZSTD_freeDCtx should never fail here"
    end
end

# For now rely on fallback `try_resize_decode!`
# Incase `try_find_decoded_size` returns `nothing`, the fall back repeatedly 
# calls `try_decode!` with larger and larger `dst`.
# This isn't ideal, but in a chunk decoding context
# the decoded size is typically found by `try_find_decoded_size`.
