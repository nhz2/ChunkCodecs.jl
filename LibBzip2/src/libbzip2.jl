# Constants and c wrapper functions ported to Julia from bzlib.h bzip2/libbzip2 version 1.0.8 of 13 July 2019

# This is needed because the header file uses the WINAPI macro when compiled for WIN32.
# This means the stdcall calling convention needs to be used on WIN32.
const WIN32 = Sys.iswindows() && Sys.WORD_SIZE == 32

const BZ_RUN              = Cint(0)
const BZ_FLUSH            = Cint(1)
const BZ_FINISH           = Cint(2)

const BZ_OK               = Cint(0)
const BZ_RUN_OK           = Cint(1)
const BZ_FLUSH_OK         = Cint(2)
const BZ_FINISH_OK        = Cint(3)
const BZ_STREAM_END       = Cint(4)
const BZ_SEQUENCE_ERROR   = Cint(-1)
const BZ_PARAM_ERROR      = Cint(-2)
const BZ_MEM_ERROR        = Cint(-3)
const BZ_DATA_ERROR       = Cint(-4)
const BZ_DATA_ERROR_MAGIC = Cint(-5)
const BZ_IO_ERROR         = Cint(-6)
const BZ_UNEXPECTED_EOF   = Cint(-7)
const BZ_OUTBUFF_FULL     = Cint(-8)
const BZ_CONFIG_ERROR     = Cint(-9)

@assert typemax(Csize_t) ≥ typemax(Cint)

function bzalloc(::Ptr{Cvoid}, m::Cint, n::Cint)::Ptr{Cvoid}
    s, f = Base.Checked.mul_with_overflow(m, n)
    if f || signbit(s)
        C_NULL
    else
        ccall(:jl_malloc, Ptr{Cvoid}, (Csize_t,), s%Csize_t)
    end
end
bzfree(::Ptr{Cvoid}, p::Ptr{Cvoid}) = ccall(:jl_free, Cvoid, (Ptr{Cvoid},), p)

mutable struct BZStream
    next_in::Ptr{Cchar}
    avail_in::Cuint
    total_in_lo32::Cuint
    total_in_hi32::Cuint

    next_out::Ptr{Cchar}
    avail_out::Cuint
    total_out_lo32::Cuint
    total_out_hi32::Cuint

    state::Ptr{Cvoid}

    bzalloc::Ptr{Cvoid}
    bzfree::Ptr{Cvoid}
    opaque::Ptr{Cvoid}

    function BZStream()
        new(
            C_NULL, 0, 0, 0,
            C_NULL, 0, 0, 0,
            C_NULL,
            @cfunction(bzalloc, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Cint)),
            @cfunction(bzfree, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid})),
            C_NULL,
        )
    end
end

function BZ2_bzCompressInit(stream::BZStream, blockSize100k::Cint)
    @static if WIN32
        ret = ccall(
            ("BZ2_bzCompressInit@16", libbzip2),
            stdcall,
            Cint,
            (Ref{BZStream}, Cint, Cint, Cint),
            stream, blockSize100k, 0, 0,
        )
    else
        ret = ccall(
            (:BZ2_bzCompressInit, libbzip2),
            Cint,
            (Ref{BZStream}, Cint, Cint, Cint),
            stream, blockSize100k, 0, 0,
        )
    end
    # error out if init failed
    if ret != BZ_OK
        if ret == BZ_CONFIG_ERROR
            error("BZ_CONFIG_ERROR the library has been mis-compiled")
        elseif ret == BZ_PARAM_ERROR
            error("BZ_PARAM_ERROR this should be unreachable")
        elseif ret == BZ_MEM_ERROR
            throw(OutOfMemoryError())
        else
            error("Unknown bzip2 error code: $(ret)")
        end
    end
    nothing
end

function BZ2_bzCompress(stream::BZStream, action::Cint)::Cint
    @static if WIN32
        ccall(
            ("BZ2_bzCompress@8", libbzip2),
            stdcall,
            Cint,
            (Ref{BZStream}, Cint),
            stream, action,
        )
    else
        ccall(
            (:BZ2_bzCompress, libbzip2),
            Cint,
            (Ref{BZStream}, Cint),
            stream, action,
        )
    end
end

function BZ2_bzCompressEnd(stream::BZStream)
    # free bzip2 stream state, not much to do if this fails
    if stream.state != C_NULL
        @static if WIN32
            ccall(
                ("BZ2_bzCompressEnd@4", libbzip2),
                stdcall,
                Cint,
                (Ref{BZStream},),
                stream,
            )
        else
            ccall(
                (:BZ2_bzCompressEnd, libbzip2),
                Cint,
                (Ref{BZStream},),
                stream,
            )
        end
    end
    nothing
end

function BZ2_bzDecompressInit(stream::BZStream)
    @static if WIN32
        ret = ccall(
                ("BZ2_bzDecompressInit@12", libbzip2),
                stdcall,
                Cint,
                (Ref{BZStream}, Cint, Cint),
                stream, 0, 0,
        )
    else
        ret = ccall(
                (:BZ2_bzDecompressInit, libbzip2),
                Cint,
                (Ref{BZStream}, Cint, Cint),
                stream, 0, 0,
        )
    end
    # error out if init failed
    if ret != BZ_OK
        if ret == BZ_CONFIG_ERROR
            error("BZ_CONFIG_ERROR the library has been mis-compiled")
        elseif ret == BZ_PARAM_ERROR
            error("BZ_PARAM_ERROR this should be unreachable")
        elseif ret == BZ_MEM_ERROR
            throw(OutOfMemoryError())
        else
            error("unknown bzip2 error code: $(ret)")
        end
    end
    nothing
end

function BZ2_bzDecompress(stream::BZStream)::Cint
    @static if WIN32
        ccall(
            ("BZ2_bzDecompress@4", libbzip2),
            stdcall,
            Cint,
            (Ref{BZStream},),
            stream,
        )
    else
        ccall(
            (:BZ2_bzDecompress, libbzip2),
            Cint,
            (Ref{BZStream},),
            stream,
        )
    end
end

function BZ2_bzDecompressEnd(stream::BZStream)
    # free bzip2 stream state, not much to do if this fails
    if stream.state != C_NULL
        @static if WIN32
            ccall(
                ("BZ2_bzDecompressEnd@4", libbzip2),
                stdcall,
                Cint,
                (Ref{BZStream},),
                stream,
            )
        else
            ccall(
                (:BZ2_bzDecompressEnd, libbzip2),
                Cint,
                (Ref{BZStream},),
                stream,
            )
        end
    end
    nothing
end


# The following is the original license info from bzlib.h and LICENSE

#=
/*-------------------------------------------------------------*/
/*--- Public header file for the library.                   ---*/
/*---                                               bzlib.h ---*/
/*-------------------------------------------------------------*/

/* ------------------------------------------------------------------
   This file is part of bzip2/libbzip2, a program and library for
   lossless, block-sorting data compression.

   bzip2/libbzip2 version 1.0.8 of 13 July 2019
   Copyright (C) 1996-2019 Julian Seward <jseward@acm.org>

   Please read the WARNING, DISCLAIMER and PATENTS sections in the 
   README file.

   This program is released under the terms of the license contained
   in the file LICENSE.
   ------------------------------------------------------------------ */
=#

#= contents of LICENSE
This program, "bzip2", the associated library "libbzip2", and all
documentation, are copyright (C) 1996-2019 Julian R Seward.  All
rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. The origin of this software must not be misrepresented; you must 
   not claim that you wrote the original software.  If you use this 
   software in a product, an acknowledgment in the product 
   documentation would be appreciated but is not required.

3. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original software.

4. The name of the author may not be used to endorse or promote 
   products derived from this software without specific prior written 
   permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Julian Seward, jseward@acm.org
bzip2/libbzip2 version 1.0.8 of 13 July 2019
=#