# This is used on Julia version that have the Base.Ryu module.

using Base.Ryu

function plain_precision_heuristic(xs::AbstractArray{<:AbstractFloat})
    ys = filter(isfinite, xs)
    precision = 0
    for y in ys
        b, e10 = Ryu.reduce_shortest(convert(Float32, y))
        precision = max(precision, -e10)
    end
    return max(precision, 0)
end

# Print a floating point number at fixed precision. Pretty much equivalent to
# @sprintf("%0.$(precision)f", x), without the macro issues.
function format_fixed(x::AbstractFloat, precision::Integer)
    @assert precision >= 0

    if x == Inf
        return "∞"
    elseif x == -Inf
        return "-∞"
    elseif isnan(x)
        return "NaN"
    end

    return Ryu.writefixed(x, precision)
end

# Print a floating point number in scientific notation at fixed precision. Sort of equivalent
# to @sprintf("%0.$(precision)e", x), but prettier printing.
function format_fixed_scientific(x::AbstractFloat, precision::Integer,
                                 engineering::Bool)
    if iszero(x)
        return "0"
    elseif isinf(x)
        return signbit(x) ? "-∞" : "∞"
    elseif isnan(x)
        return "NaN"
    end

    if engineering
        b, e10 = Ryu.reduce_shortest(convert(Float32, x))
        d, r = divrem(e10, 3)
        if d < 0 &&
            d += sign(r)

    end
    ryustr = Ryu.writeexp(x, precision)
    @show x ryustr

    # Rewrite the exponent
    buf = IOBuffer()
    ret = iterate(ryustr)
    while ret !== nothing
        c, state = ret
        c === 'e' && break
        print(buf, c)
        ret = iterate(ryustr, state)
    end
    if ret !== nothing
        print(buf, "×10")
        _, state = ret
        ret = iterate(ryustr, state)
        while ret !== nothing
            c, state = ret
            if '0' <= c <= '9'
                print(buf, superscript_numerals[c - '0' + 1])
            elseif c == '-'
                print(buf, '⁻')
            end
            ret = iterate(ryustr, state)
        end
    end

    return String(take!(buf))
end

