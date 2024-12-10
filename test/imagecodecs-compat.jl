using PythonCall
using ChunkCodecs
using Test

codecs = [
    (ChunkCodecLibBlosc.BloscEncodeOptions(),   ("blosc",   (;)), 1000),
    (ChunkCodecLibBzip2.BZ2EncodeOptions(),     ("bz2",     (;)), 50),
    (ChunkCodecLibLz4.LZ4BlockEncodeOptions(),  ("lz4",     (;header=false)), 1000),
    (ChunkCodecLibLz4.LZ4ZarrEncodeOptions(),   ("lz4",     (;header=true)), 1000),
    (ChunkCodecLibLz4.LZ4FrameEncodeOptions(),  ("lz4f",    (;)), 1000),
    (ChunkCodecLibZlib.ZlibEncodeOptions(),     ("zlib",    (;)), 100),
    (ChunkCodecLibZlib.DeflateEncodeOptions(),  ("deflate", (;raw=true), 0b10), 300), # encode only
    (ChunkCodecLibZlib.GzipEncodeOptions(),     ("gzip",    (;)), 100),
    (ChunkCodecLibZstd.ZstdEncodeOptions(),     ("zstd",    (;)), 300),
]

@testset "$(jl_options) $(im_options)" for (jl_options, im_options, trials) in codecs
    im_name = im_options[1]
    im_enc_funct, im_dec_funct = pyimport("imagecodecs" => ("$(im_name)_encode", "$(im_name)_decode"))
    im_enc(x) = pyconvert(Vector, im_enc_funct(x; im_options[2]...))
    im_dec(x) = pyconvert(Vector, im_dec_funct(x; im_options[2]...))
    jl_dec(x) = decode(codec(jl_options), x)
    jl_enc(x) = encode(jl_options, x)
    srange = ChunkCodecCore.decoded_size_range(jl_options)
    # round trip tests
    decoded_sizes = [
        first(srange):step(srange):min(last(srange), first(srange)+10*step(srange));
        rand(first(srange):step(srange):min(last(srange), 2000000), trials);
    ]
    for s in decoded_sizes
        # generate data
        local choice = rand(1:4)
        local data = if choice == 1
            rand(UInt8, s)
        elseif choice == 2
            zeros(UInt8, s)
        elseif choice == 3
            ones(UInt8, s)
        elseif choice == 4
            rand(0x00:0x0f, s)
        end
        has_encode, has_decode = if length(im_options) ≤ 2
            true, true
        else
            !iszero(im_options[3] & 2), !iszero(im_options[3] & 1)
        end
        if has_encode
            @test jl_dec(im_enc(data)) == data
        end
        if has_decode
            @test im_dec(jl_enc(data)) == data
        end
    end
end