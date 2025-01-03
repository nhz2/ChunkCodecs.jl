# The Noop codec

"""
    struct NoopCodec <: Codec
    NoopCodec()

This codec copies the input.

See also [`NoopEncodeOptions`](@ref) and [`NoopDecodeOptions`](@ref)
"""
struct NoopCodec <: Codec end
can_concatenate(::NoopCodec) = true
decode_options(::NoopCodec) = NoopDecodeOptions() # default decode options

"""
    struct NoopEncodeOptions <: EncodeOptions
    NoopEncodeOptions(::NoopCodec=NoopCodec(); kwargs...)

Copies the input.
"""
struct NoopEncodeOptions <: EncodeOptions
    function NoopEncodeOptions(::NoopCodec=NoopCodec();
            kwargs...
        )
        new()
    end
end
codec(::NoopEncodeOptions) = NoopCodec()

is_thread_safe(::NoopEncodeOptions) = true

decoded_size_range(::NoopEncodeOptions) = Int64(0):Int64(1):typemax(Int64)-Int64(1)

encode_bound(::NoopEncodeOptions, src_size::Int64)::Int64 = src_size

function try_encode!(e::NoopEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    dst_size::Int64 = length(dst)
    src_size::Int64 = length(src)
    check_in_range(decoded_size_range(e); src_size)
    if dst_size < src_size
        nothing
    else
        copyto!(dst, src)
        src_size
    end
end

"""
    struct NoopDecodeOptions <: DecodeOptions
    NoopDecodeOptions(::NoopCodec=NoopCodec(); kwargs...)

Copies the input.
"""
struct NoopDecodeOptions <: DecodeOptions
    function NoopDecodeOptions(::NoopCodec=NoopCodec();
            kwargs...
        )
        new()
    end
end
codec(::NoopDecodeOptions) = NoopCodec()

is_thread_safe(::NoopDecodeOptions) = true

function try_find_decoded_size(::NoopDecodeOptions, src::AbstractVector{UInt8})::Int64
    length(src)
end

function try_decode!(::NoopDecodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    dst_size::Int64 = length(dst)
    src_size::Int64 = length(src)
    if dst_size < src_size
        nothing
    else
        copyto!(dst, src)
        src_size
    end
end
