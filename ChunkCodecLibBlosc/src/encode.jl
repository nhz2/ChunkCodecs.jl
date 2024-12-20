"""
    struct BloscEncodeOptions <: EncodeOptions
    BloscEncodeOptions(::BloscCodec=BloscCodec(); kwargs...)

Blosc compression using c-blosc library: https://github.com/Blosc/c-blosc

# Keyword Arguments

- `clevel::Integer=5`: The compression level, between 0 (no compression) and 9 (maximum compression)
- `doshuffle::Integer=1`: Whether to use the shuffle filter.
0 means not applying it, 1 means applying it at a byte level,
and 2 means at a bit level (slower but may achieve better entropy alignment).
- `typesize::Integer=1`: The element size to use when shuffling.
For implementation reasons, only `typesize` in `1:$(BLOSC_MAX_TYPESIZE)` will allow the
shuffle filter to work.  When `typesize` is not in this range, shuffle
will be silently disabled.
- `compressor::AbstractString="lz4"`: The string representing the type of 
compressor to use. For example, "blosclz", "lz4", "lz4hc", "zlib", or "zstd".
Use `is_compressor_valid` to check if a compressor is supported.
- `blocksize::Integer=0`: The requested size of the compressed blocks. If 0, an
automatic blocksize will be used.
- `numinternalthreads::Integer=1`: The number of threads to use internally,
Must be in `1:$(BLOSC_MAX_THREADS)`.
"""
struct BloscEncodeOptions <: EncodeOptions
    clevel::Cint
    doshuffle::Cint
    typesize::Csize_t
    compressor::String
    blocksize::Csize_t
    numinternalthreads::Cint
end
codec(::BloscEncodeOptions) = BloscCodec()

function BloscEncodeOptions(::BloscCodec=BloscCodec();
        clevel::Integer=5,
        doshuffle::Integer=1,
        typesize::Integer=1,
        compressor::AbstractString="lz4",
        blocksize::Integer=0,
        numinternalthreads::Integer=1,
        kwargs...
    )
    check_in_range(0:9; clevel)
    check_in_range(0:2; doshuffle)
    _typesize = if typesize ∈ 2:BLOSC_MAX_TYPESIZE
        Csize_t(typesize)
    else
        Csize_t(1)
    end
    is_compressor_valid(compressor) || throw(ArgumentError("is_compressor_valid(compressor) must hold. Got\ncompressor => $(repr(compressor))"))
    check_in_range(typemin(Csize_t):typemax(Csize_t); blocksize)
    check_in_range(1:BLOSC_MAX_THREADS; numinternalthreads)
    BloscEncodeOptions(
        clevel,
        doshuffle,
        _typesize,
        compressor,
        blocksize,
        numinternalthreads,
    )
end

# TODO update this when segfault is fixed upstream.
decoded_size_range(e::BloscEncodeOptions) = Int64(0):Int64(e.typesize):Int64(2)^30

encode_bound(::BloscEncodeOptions, src_size::Int64)::Int64 = Base.Checked.checked_add(src_size, BLOSC_MAX_OVERHEAD)

function try_encode!(e::BloscEncodeOptions, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::Union{Nothing, Int64}
    check_contiguous(dst)
    check_contiguous(src)
    src_size::Int64 = length(src)
    check_in_range(decoded_size_range(e); src_size)
    sz = ccall((:blosc_compress_ctx, libblosc), Cint,
        (Cint, Cint, Csize_t, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Cstring, Csize_t, Cint),
        e.clevel, e.doshuffle, e.typesize, length(src), src, dst, length(dst), e.compressor, e.blocksize, e.numinternalthreads
    )
    if sz == 0
        nothing
    elseif sz < 0
        error("Internal Blosc error: $(sz). This
            should never happen.  If you see this, please report it back
            together with the buffer data causing this and compression settings.
            $(e)
        ")
    else
        Int64(sz)
    end
end
