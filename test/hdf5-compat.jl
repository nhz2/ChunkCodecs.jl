include("hdf5_helpers.jl")

using HDF5
using ChunkCodecs
using ChunkCodecTests: rand_test_data
using Test
# TODO trigger HDF5 filter loading


# List of encode options and filter ids and client datas
codecs = [
    [(
        ChunkCodecLibZlib.ZlibEncodeOptions(;level),
        ([0x0001], [[UInt32(level)]]),
        200,
    ) for level in 0:9];
    [(
        ChunkCodecCore.ShuffleEncodeOptions(ChunkCodecCore.ShuffleCodec(element_size)),
        ([0x0002], [[UInt32(element_size)]]),
        200,
    ) for element_size in [1:20; 1023; typemax(UInt32);]];
]

@testset "$(jl_options) $(h5_options)" for (jl_options, h5_options, trials) in codecs
    h5file = tempname()
    srange = ChunkCodecCore.decoded_size_range(jl_options)
    # round trip tests
    decoded_sizes = [
        first(srange):step(srange):min(last(srange), first(srange)+10*step(srange));
        rand(first(srange):step(srange):min(last(srange), 2000000), trials);
    ]
    for s in decoded_sizes
        # HDF5 cannot handle zero sized chunks
        iszero(s) && continue
        local data = rand_test_data(s)
        chunk = encode(jl_options, data)
        mktemp() do path, io
            write(io, make_hdf5(chunk, s, h5_options...))
            close(io)
            h5open(path, "r") do f
                h5_decoded = collect(f["test-data"])
                @test h5_decoded == data
            end
        end
    end
end
