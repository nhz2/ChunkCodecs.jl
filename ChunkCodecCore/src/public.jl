@static if VERSION ≥ v"1.11.0-DEV.469"
    macro public(s::Symbol)
        return esc(Expr(:public, s))
    end
    macro public(e::Expr)
        return esc(Expr(:public, e.args...))
    end
else
    macro public(e) end
end

@doc("""
    @public foo, [bar...]

A simplified public macro for private use by ChunkCodecs

In Julia 1.10 or earlier, the macro is only an annotation
and performs no operation.

In Julia 1.11 and later, the macro uses the `public` keyword.

This macro is meant to be simple only deals with symbols or
tuple expressions. It does not handle macro calls or do any
validation. Validate effectiveness in testing via
`Base.ispublic`.
""", :(ChunkCodecCore.@public))
