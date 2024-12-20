"""
    encode(e, src::AbstractVector{UInt8})::Vector{UInt8}

Encode the input vector `src` using encoder `e`.
`e` must implement [`decoded_size_range`](@ref),
[`encode_bound`](@ref), and [`try_encode!`](@ref).

Throw an error if `length(src)` is not in `decoded_size_range(e)`

Otherwise throw an error.

See also [`EncodeOptions`](@ref).
"""
function encode(e, src::AbstractVector{UInt8})::Vector{UInt8}
    src_size::Int64 = length(src)
    check_in_range(decoded_size_range(e); src_size)
    dst_size::Int64 = encode_bound(e, src_size)
    @assert !signbit(dst_size)
    dst = Vector{UInt8}(undef, dst_size)
    real_dst_size = something(try_encode!(e, dst, src))
    @assert real_dst_size ∈ 0:dst_size
    resize!(dst, real_dst_size)
    dst
end

"""
    decode(d, src::AbstractVector{UInt8}; max_size::Integer=typemax(Int64), size_hint::Integer=Int64(0))::Vector{UInt8}

Decode the input data `src` using decoder `d`.
`d` must implement [`try_find_decoded_size`](@ref), [`try_decode!`](@ref), and optionally [`try_resize_decode!`](@ref).

Throw a [`DecodedSizeError`](@ref) if decoding fails because the output size would be greater than `max_size`.

Throw a [`DecodingError`](@ref) if decoding fails because the input data is not valid.

Otherwise throw an error.

If you have a good idea of what the decoded size is, using the `size_hint` keyword argument
can greatly improve performance.

See also [`DecodeOptions`](@ref).
"""
function decode(
        d,
        src::AbstractVector{UInt8};
        max_size::Integer=typemax(Int64),
        size_hint::Integer=Int64(0),
    )::Vector{UInt8}
    _clamp_max_size::Int64 = clamp(max_size, Int64)
    if _clamp_max_size < Int64(0)
        throw(DecodedSizeError(_clamp_max_size, nothing))
    end
    _clamp_size_hint::Int64 = clamp(size_hint, Int64(0), _clamp_max_size)
    dst = zeros(UInt8, _clamp_size_hint)
    real_dst_size = try_resize_decode!(d, dst, src; max_size=_clamp_max_size)::Union{Nothing, Int64}
    if isnothing(real_dst_size)
        throw(DecodedSizeError(_clamp_max_size, try_find_decoded_size(d, src)))
    end
    @assert !signbit(real_dst_size)
    if real_dst_size < _clamp_size_hint
        resize!(dst, real_dst_size)
    end
    @assert real_dst_size == length(dst)
    dst
end

"""
    decode_options(::Codec)::DecodeOptions

Return the default decode options for the codec.
"""
function decode_options end

"""
    can_concatenate(::Codec)::Bool

Return `true` if the codec has concatenation transparency.

If `true`, and some encoded data `a` and `b` decode to `x` and `y` respectively, then
the concatenation of `a` and `b` will
decode to the concatenation of `x` and `y`
"""
can_concatenate(::Codec) = false

"""
    codec(e)::Codec

Return the codec associated with the encoding or decoding options.
The codec contains the information required for decoding.
"""
function codec end

"""
    decoded_size_range(e)::StepRange{Int64, Int64}

Return the range of allowed `src` sizes for encoding.
[`encode_bound`](@ref) must not overflow for any `src_size` in this range.
"""
function decoded_size_range end

"""
    encode_bound(e, src_size::Int64)::Int64

Return the size of `dst` required to ensure [`try_encode!`](@ref) succeeds regardless of `src`'s content.

Precondition: `src_size` is in [`decoded_size_range(e)`](@ref)
"""
function encode_bound end

"""
    try_encode!(e, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}

Try to encode `src` into `dst` using encoder `e`.

Return the size of the encoded output in `dst` if successful.

If `dst` is too small, return `nothing`.

Throw an error if `length(src)` is not in `decoded_size_range(e)`

Otherwise throw an error.

Precondition: `dst` and `src` do not overlap in memory.

All of `dst` can be written to or used as scratch space by the encoder.
Only the initial returned number of bytes are valid output.

See also [`encode_bound`](@ref) and [`decoded_size_range`](@ref)
"""
function try_encode! end

"""
    is_thread_safe(::Union{Codec, DecodeOptions, EncodeOptions})::Bool

Return `true` if it is safe to use the the options to encode or decode concurrently in multiple threads.
"""
is_thread_safe(::EncodeOptions) = false
is_thread_safe(::DecodeOptions) = false
is_thread_safe(c::Codec) = is_thread_safe(decode_options(c))

"""
    try_find_decoded_size(d, src::AbstractVector{UInt8})::Union{Nothing, Int64}

Try to return the size of the decoded output of `src` using `d`.

If the size cannot be quickly determined, return `nothing`.

If the encoded data is found to be invalid, throw a `DecodingError`.

This if an `Int64` is returned, it must be the exact size of the decoded output.
If [`try_decode!`](@ref) is called with a `dst` of this size, it must succeed and return the same size, or throw an error.
"""
function try_find_decoded_size end

"""
    try_decode!(d, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}

Try to decode `src` into `dst` using decoder `d`.

Return the size of the decoded output in `dst` if successful.

If `dst` is too small to fit the decoded output, return `nothing`.

Throw a [`DecodingError`](@ref) if decoding fails because the input data is not valid.

Otherwise throw an error.

Precondition: `dst` and `src` do not overlap in memory.

All of `dst` can be written to or used as scratch space by the decoder.
Only the initial returned number of bytes are valid output.
"""
function try_decode! end

"""
    try_resize_decode!(d, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; max_size::Int64=typemax(Int64), kwargs...)::Union{Nothing, Int64}

Try to decode the input `src` into `dst` using decoder `d`.

Return the size of the decoded output in `dst` if successful.

If `dst` is too small, resize `dst` and try again.
If the `max_size` limit will be passed, return `nothing`.

`dst` can be resized using the `resize!` function to any size between the original length of `dst` and `max_size`.

Throw an `ArgumentError` if `length(dst)` is not in `0:max_size`.

Precondition: `dst` and `src` do not overlap in memory.

All of `dst` can be written to or used as scratch space by the decoder.
Only the initial returned number of bytes are valid output.
"""
function try_resize_decode!(d, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; max_size::Int64=typemax(Int64), kwargs...)::Union{Nothing, Int64}
    check_in_range(Int64(0):max_size; dst_size=length(dst))
    olb::Int64 = length(dst)
    real_dst_size::Int64 = -1
    decoded_size = try_find_decoded_size(d, src)::Union{Nothing, Int64}
    if isnothing(decoded_size)
        while true
            ds = try_decode!(d, dst, src)::Union{Nothing, Int64}
            if isnothing(ds)
                # grow dst
                local cur_size::Int64 = length(dst)
                if cur_size == max_size
                    return
                end
                @assert cur_size < max_size
                # This inequality prevents overflow
                local next_size = if max_size - cur_size ≤ cur_size
                    max_size
                else
                    max(2*cur_size, Int64(1))
                end
                resize!(dst, next_size)
            else
                real_dst_size = ds
                break
            end
        end
    else
        if decoded_size ∉ 0:max_size
            return
        end
        if decoded_size > olb
            resize!(dst, decoded_size)
        end
        real_dst_size = something(try_decode!(d, dst, src))
        @assert real_dst_size == decoded_size
    end
    @assert real_dst_size ∈ 0:length(dst)
    if length(dst) > olb && length(dst) != real_dst_size
        @assert real_dst_size > olb
        resize!(dst, real_dst_size) # shrink to just contain output if it was resized.
    end
    return real_dst_size
end

# allow passing codec to decode
try_find_decoded_size(c::Codec, src::AbstractVector{UInt8}) = try_find_decoded_size(decode_options(c), src)
try_decode!(c::Codec, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...) = try_decode!(decode_options(c), dst, src)
try_resize_decode!(c::Codec, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...) = try_resize_decode!(decode_options(c), dst, src)


function check_contiguous(x::AbstractVector{UInt8})
    y = Base.cconvert(Ptr{UInt8}, x)
    GC.@preserve y Base.unsafe_convert(Ptr{UInt8}, y)
    isone(only(strides(x))) || throw(ArgumentError("vector is not contiguous in memory"))
    Int64(length(x))
    @assert !signbit(length(x))
    nothing
end

function check_in_range(range; kwargs...)
    for (k, v) in kwargs
        if v ∉ range
            throw(ArgumentError("$(k) ∈ $(range) must hold. Got\n$(k) => $(v)"))
        end
    end
end
