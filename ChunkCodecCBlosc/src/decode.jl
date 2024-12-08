"""
    BloscDecodingError(code)

Error for data that cannot be decoded.
"""
struct BloscDecodingError <: DecodingError
    code::Cint
end

function Base.showerror(io::IO, err::BloscDecodingError)
    print(io, "BloscDecodingError: blosc compressed buffer cannot be decoded, error code: ")
    print(io, err.code)
    nothing
end

struct BloscDecodeOptions <: DecodeOptions
    numinternalthreads::Cint
end
codec(::BloscDecodeOptions) = BloscCodec()

"""
    struct BloscDecodeOptions <: DecodeOptions
    BloscDecodeOptions(::BloscCodec=BloscCodec(); kwargs...)

Blosc decompression using c-blosc library: https://github.com/Blosc/c-blosc

# Keyword Arguments

- `numinternalthreads::Integer=1`: The number of threads to use internally,
Must be in `1:$(BLOSC_MAX_THREADS)`.

"""
function BloscDecodeOptions(::BloscCodec=BloscCodec();
        numinternalthreads::Integer=1,
        kwargs...
    )
    check_in_range(1:BLOSC_MAX_THREADS; numinternalthreads)
    BloscDecodeOptions(numinternalthreads)
end

function try_find_decoded_size(::BloscDecodeOptions, src::AbstractVector{UInt8})::Int64
    check_contiguous(src)
    nbytes = Ref(Csize_t(0))
    ret = ccall((:blosc_cbuffer_validate, libblosc), Cint,
        (Ptr{Cvoid}, Csize_t, Ptr{Csize_t}),
        src, length(src), nbytes
    )
    if iszero(ret) && nbytes[] ≤ typemax(Int64)
        # success, it is safe to decompress
        Int64(nbytes[])
    else
        # it is not safe to decompress. throw an error
        throw(BloscDecodingError(ret))
    end
end

function try_decode!(d::BloscDecodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    # This makes sure it is safe to decompress.
    nbytes = try_find_decoded_size(d, src)
    dst_size::Int64 = length(dst)
    if nbytes > dst_size
        nothing
    else
        sz = ccall((:blosc_decompress_ctx, libblosc), Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Cint),
            src, dst, dst_size, d.numinternalthreads
        )
        if sz == nbytes
            nbytes
        else
            throw(BloscDecodingError(sz))
        end
    end
end