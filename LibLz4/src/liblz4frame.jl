# Constants and c wrapper functions ported to Julia from lz4frame.h
# https://github.com/lz4/lz4/blob/v1.10.0/lib/lz4frame.h

const LZ4F_VERSION = Cuint(100) # This number can be used to check for an incompatible API breaking change
LZ4F_getVersion()::Cuint = ccall((:LZ4F_getVersion, liblz4), Cuint, ())

"""
    LZ4F_isError(ret::Csize_t)::Bool

Return true if return `ret` is an error
"""
function LZ4F_isError(ret::Csize_t)::Bool
    !iszero(ccall((:LZ4F_isError, liblz4), Cuint, (Csize_t,), ret))
end

# provides readable string from a function result
function LZ4F_getErrorName(ret::Csize_t)::String
    unsafe_string(ccall((:LZ4F_getErrorName, liblz4), Ptr{Cchar}, (Csize_t,), ret))
end

# The larger the block size, the (slightly) better the compression ratio,
# though there are diminishing returns.
# Larger blocks also increase memory usage on both compression and decompression sides.
@enum LZ4F_blockSizeID_t::Cint begin
    LZ4F_default=0
    LZ4F_max64KB=4
    LZ4F_max256KB=5
    LZ4F_max1MB=6
    LZ4F_max4MB=7
end

# Linked blocks sharply reduce inefficiencies when using small blocks,
# they compress better.
# However, some LZ4 decoders are only compatible with independent blocks
@enum LZ4F_blockMode_t::Cint begin
    LZ4F_blockLinked=0
    LZ4F_blockIndependent
end

@enum LZ4F_contentChecksum_t::Cint begin
    LZ4F_noContentChecksum=0
    LZ4F_contentChecksumEnabled
end

@enum LZ4F_blockChecksum_t::Cint begin
    LZ4F_noBlockChecksum=0
    LZ4F_blockChecksumEnabled
end

@enum LZ4F_frameType_t::Cint begin
    LZ4F_frame=0
    LZ4F_skippableFrame
end

"""
    LZ4F_frameInfo_t

makes it possible to set or read frame parameters.
Structure must be first init to 0, using memset() or LZ4F_INIT_FRAMEINFO,
setting all parameters to default.
It's then possible to update selectively some parameters
"""
struct LZ4F_frameInfo_t
    "max64KB, max256KB, max1MB, max4MB; 0 == default (LZ4F_max64KB)"
    blockSizeID::LZ4F_blockSizeID_t

    "LZ4F_blockLinked, LZ4F_blockIndependent; 0 == default (LZ4F_blockLinked)"
    blockMode::LZ4F_blockMode_t

    "1: add a 32-bit checksum of frame's decompressed data; 0 == default (disabled)"
    contentChecksumFlag::LZ4F_contentChecksum_t

    "read-only field : LZ4F_frame or LZ4F_skippableFrame"
    frameType::LZ4F_frameType_t

    "Size of uncompressed content ; 0 == unknown"
    contentSize::Culonglong

    "Dictionary ID, sent by compressor to help decoder select correct dictionary; 0 == no dictID provided"
    dictID::Cuint

    "1: each block followed by a checksum of block's compressed data; 0 == default (disabled)"
    blockChecksumFlag::LZ4F_blockChecksum_t
end

const LZ4F_INIT_FRAMEINFO = LZ4F_frameInfo_t(LZ4F_max64KB, LZ4F_blockLinked, LZ4F_noContentChecksum, LZ4F_frame, Culonglong(0), Cuint(0), LZ4F_noBlockChecksum)

"""
    LZ4F_preferences_t

makes it possible to supply advanced compression instructions to streaming interface.
Structure must be first init to 0, using memset() or LZ4F_INIT_PREFERENCES,
setting all parameters to default.
All reserved fields must be set to zero.
"""
struct LZ4F_preferences_t
    frameInfo::LZ4F_frameInfo_t

    "0: default (fast mode); values > LZ4HC_CLEVEL_MAX count as LZ4HC_CLEVEL_MAX; values < 0 trigger fast acceleration"
    compressionLevel::Cint

    "1: always flush; reduces usage of internal buffers"
    autoFlush::Cuint

    "1: parser favors decompression speed vs compression ratio. Only works for high compression modes (>= LZ4HC_CLEVEL_OPT_MIN)   v1.8.2+ "
    favorDecSpeed::Cuint

    # must be zero for forward compatibility
    reserved::NTuple{3, Cuint}
end

const LZ4F_INIT_PREFERENCES = LZ4F_preferences_t(LZ4F_INIT_FRAMEINFO, Cint(0), Cuint(0), Cuint(0), (Cuint(0), Cuint(0), Cuint(0)))    # /* v1.8.3+ */

#  LZ4F_compressFrame() :
#  Compress srcBuffer content into an LZ4-compressed frame.
#  It's a one shot operation, all input content is consumed, and all output is generated.
#
#  Note : it's a stateless operation (no LZ4F_cctx state needed).
#  In order to reduce load on the allocator, LZ4F_compressFrame(), by default,
#  uses the stack to allocate space for the compression state and some table.
#  If this usage of the stack is too much for your application,
#  consider compiling `lz4frame.c` with compile-time macro LZ4F_HEAPMODE set to 1 instead.
#  All state allocations will use the Heap.
#  It also means each invocation of LZ4F_compressFrame() will trigger several internal alloc/free invocations.
#
# @dstCapacity MUST be >= LZ4F_compressFrameBound(srcSize, preferencesPtr).
# @preferencesPtr is optional : one can provide NULL, in which case all preferences are set to default.
# @return : number of bytes written into dstBuffer.
#           or an error code if it fails (can be tested using LZ4F_isError())
# 
function LZ4F_compressFrame(
        dst::AbstractVector{UInt8},
        src::AbstractVector{UInt8},
        preferences::LZ4F_preferences_t,
    )::Csize_t
    ccall(
        (:LZ4F_compressFrame, liblz4), Csize_t,
        (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Csize_t, Ref{LZ4F_preferences_t}),
        dst, length(dst), src, length(src), Ref(preferences),
    )
end

# /*! LZ4F_compressFrameBound() :
#  *  Returns the maximum possible compressed size with LZ4F_compressFrame() given srcSize and preferences.
#  * `preferencesPtr` is optional. It can be replaced by NULL, in which case, the function will assume default preferences.
#  *  Note : this result is only usable with LZ4F_compressFrame().
#  *         It may also be relevant to LZ4F_compressUpdate() _only if_ no flush() operation is ever performed.
#  */
# If Csize_t is 64 bits, to be safe, a srcSize less than 2^47-2 doesn't overflow
# If Csize_t is 32 bits, to be safe, a srcSize less than 2^31-2 doesn't overflow
function LZ4F_compressFrameBound(srcSize::Csize_t, preferences::LZ4F_preferences_t,)::Csize_t
    ccall(
        (:LZ4F_compressFrameBound, liblz4), Csize_t,
        (Csize_t, Ref{LZ4F_preferences_t}),
        srcSize, Ref(preferences),
    )
end


# Just used to mark the type of pointers
mutable struct LZ4F_dctx end

struct LZ4F_decompressOptions_t
    """
    pledges that last 64KB decompressed data is present right before @dstBuffer pointer.
    This optimization skips internal storage operations.
    Once set, this pledge must remain valid up to the end of current frame.
    """
    stableDst::Cuint

    """
    disable checksum calculation and verification, even when one is present in frame, to save CPU time.
    Setting this option to 1 once disables all checksums for the rest of the frame.
    """
    skipChecksums::Cuint

    reserved1::Cuint # must be set to zero for forward compatibility
    reserved0::Cuint # idem
end

function LZ4F_createDecompressionContext()::Ptr{LZ4F_dctx}
    dctxPtr = Ref(Ptr{LZ4F_dctx}())
    ret = ccall(
        (:LZ4F_createDecompressionContext, liblz4), Csize_t,
        (Ref{Ptr{LZ4F_dctx}}, Cuint),
        dctxPtr, LZ4F_VERSION,
    )
    if LZ4F_isError(ret)
        throw(OutOfMemoryError())
    else
        dctxPtr[]
    end
end
function LZ4F_freeDecompressionContext(dctx::Ptr{LZ4F_dctx})::Nothing
    ccall(
        (:LZ4F_freeDecompressionContext, liblz4), Csize_t,
        (Ptr{LZ4F_dctx},),
        dctx,
    )
    # ignore errors
    nothing
end



# The following is the original license info from lz4frame.h

#=
   LZ4F - LZ4-Frame library
   Header File
   Copyright (C) 2011-2020, Yann Collet.
   BSD 2-Clause License (http://www.opensource.org/licenses/bsd-license.php)

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:

       * Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
       * Redistributions in binary form must reproduce the above
   copyright notice, this list of conditions and the following disclaimer
   in the documentation and/or other materials provided with the
   distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   You can contact the author at :
   - LZ4 source repository : https://github.com/lz4/lz4
   - LZ4 public forum : https://groups.google.com/forum/#!forum/lz4c
=#
