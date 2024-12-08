"""
    abstract type Codec

This contains the information required to decode.

A type `T <: Codec` must implement the following:
- `decode_options(::T)::DecodeOptions`: The default decoding options.

The following are optional methods with default fallbacks:
- `can_concatenate(::T)::Bool`: defaults to `false`.
"""
abstract type Codec end

"""
    abstract type EncodeOptions

Options to use when encoding.

A type `T <: EncodeOptions` must implement the following:
- `codec(::T)::Codec`
- `decoded_size_range(::T)::StepRange{Int64, Int64}`
- `encoded_bound(::T, src_size::Int64)::Int64`
- `try_encode!(::T, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}`

The following are optional methods with default fallbacks:
- `is_thread_safe(::T)::Bool`: defaults to `false`.
"""
abstract type EncodeOptions end


"""
    abstract type DecodeOptions

Options to use when decoding.

A type `T <: DecodeOptions` must implement the following:
- `codec(::T)::Codec`
- `try_find_decoded_size(::T, src::AbstractVector{UInt8})::Union{Nothing, Int64}`
- `try_decode!(::T, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}`

The following are optional methods with default fallbacks:
- `is_thread_safe(::T)::Bool`: defaults to `false`.
- `try_resize_decode!(::T, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; max_size::Int64=typemax(Int64), kwargs...)::Union{Nothing, Int64}`: defaults to using `try_decode!` and `try_find_decoded_size`
"""
abstract type DecodeOptions end