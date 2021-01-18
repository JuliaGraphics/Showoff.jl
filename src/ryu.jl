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
        base_digits, power = get_engineering_string(x, precision)
    else
        e_format_number = Ryu.writeexp(x, precision)
        base_digits, power = split(e_format_number, 'e')
    end


    buf = IOBuffer()

    print(buf, base_digits)
    print(buf, "×10")

    if power[1] == '-'
        print(buf, '⁻')
    end
    leading_index = findfirst(c -> '1' <= c <= '9', power)

    if isnothing(leading_index)
        print(buf, superscript_numerals[1])
        return String(take!(buf))
    end

    for (i,c) in enumerate(power[leading_index:end])
        if c == '-'
            print(buf, '⁻')
        elseif '0' <= c <= '9'
            print(buf, superscript_numerals[c - '0' + 1])
        end

    end

    String(take!(buf))
end


function get_engineering_string(x::AbstractFloat, precision::Integer)
    e_format_number = Ryu.writeexp(x, precision)
    base_digits, power = split(e_format_number, 'e')

    int_power = parse(Int, power)
    positive = int_power >= 0

    # round the power to the nearest multiple of 3
    # positive power -> move the "." to the right by mode, round the power to the higher power
    # negative power -> move the "." to the right by mode, round the power to the lower power
    # ex:
    # 1.2334e5 = 123.334e3
    # 1.2334-5 = 12.3334e-6

    if positive
        indices_to_move = int_power - floor(Int, int_power/3) * 3
    else
        indices_to_move = ceil(Int, abs(int_power)/3) * 3 - abs(int_power)
    end

    buf = IOBuffer()
    for i in eachindex(base_digits)
        if base_digits[i] != '.'
            print(buf, base_digits[i])
        end
        if i == 2 + indices_to_move
            print(buf, '.')
        end
    end

    return String(take!(buf)), string(int_power - indices_to_move)
end
