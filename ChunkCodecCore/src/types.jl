"""
    abstract type Codec

Required information to decode encoded data.

Required methods for a type `T <: Codec` to implement:
- `decode_options(::T)::DecodeOptions`

Optional methods to implement:
- `can_concatenate(::T)::Bool`: defaults to `false`.
"""
abstract type Codec end

"""
    abstract type EncodeOptions

Options for encoding data.

Required methods for a type `T <: EncodeOptions` to implement:
- `codec(::T)::Codec`
- `decoded_size_range(::T)::StepRange{Int64, Int64}`
- `encode_bound(::T, src_size::Int64)::Int64`
- `try_encode!(::T, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}`

Optional methods to implement:
- `is_thread_safe(::T)::Bool`: defaults to `false`.
"""
abstract type EncodeOptions end


"""
    abstract type DecodeOptions

Options for decoding data.

Required methods for a type `T <: DecodeOptions` to implement:
- `codec(::T)::Codec`
- `try_find_decoded_size(::T, src::AbstractVector{UInt8})::Union{Nothing, Int64}`
- `try_decode!(::T, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}`

Optional methods to implement:
- `is_thread_safe(::T)::Bool`: defaults to `false`.
- `try_resize_decode!(::T, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; max_size::Int64=typemax(Int64), kwargs...)::Union{Nothing, Int64}`: defaults to using `try_decode!` and `try_find_decoded_size`
"""
abstract type DecodeOptions end