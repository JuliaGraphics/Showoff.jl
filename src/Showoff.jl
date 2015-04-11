module Showoff

using Compat
using Iterators: drop

export showoff


# suppress compile errors when there isn't a grisu_ccall macro
if VERSION >= v"0.4-dev"
    macro grisu_ccall(x, mode, ndigits)
        quote end
    end
else
    import Base.Grisu.@grisu_ccall
end


function grisu(v::FloatingPoint, mode, requested_digits)
    if VERSION < v"0.4-dev"
        if isa(v, Float32) && mode == Base.Grisu.SHORTEST
            mode = Base.Grisu.SHORTEST_SINGLE
        end
        @grisu_ccall v mode requested_digits
        return Base.Grisu.LEN[1], Base.Grisu.POINT[1], Base.Grisu.NEG, Base.Grisu.DIGITS
    else
        return Base.Grisu.grisu(v, mode, requested_digits)
    end
end


# Fallback
function showoff(xs::AbstractArray, style=:none)
    result = Array(String, length(xs))
    buf = IOBuffer()
    for (i, x) in enumerate(xs)
        show(buf, x)
        result[i] = takebuf_string(buf)
    end

    return result
end


# Floating-point

function concrete_minimum(xs)
    if done(xs, start(xs))
        error("argument must not be empty")
    end

    x_min = first(xs)
    for x in xs
        if isa(x, FloatingPoint) && isfinite(x)
            x_min = x
            break
        end
    end

    for x in xs
        if isa(x, FloatingPoint) && isfinite(x) && x < x_min
            x_min = x
        end
    end
    return x_min
end


function concrete_maximum(xs)
    if done(xs, start(xs))
        error("argument must not be empty")
    end

    x_max = first(xs)
    for x in xs
        if isa(x, FloatingPoint) && isfinite(x)
            x_max = x
            break
        end
    end

    for x in xs
        if isa(x, FloatingPoint) && isfinite(x) && x > x_max
            x_max = x
        end
    end
    return x_max
end


function plain_precision_heuristic{T <: FloatingPoint}(xs::AbstractArray{T})
    ys = filter(isfinite, xs)
    precision = 0
    for y in ys
        len, point, neg, digits = grisu(convert(Float32, y), Base.Grisu.SHORTEST, 0)
        precision = max(precision, len - point)
    end
    return max(precision, 0)
end


function scientific_precision_heuristic{T <: FloatingPoint}(xs::AbstractArray{T})
    ys = [x == 0.0 ? 0.0 : x / 10.0^floor(log10(abs(x)))
          for x in filter(isfinite, xs)]
    return plain_precision_heuristic(ys) + 1
end


function showoff{T <: FloatingPoint}(xs::AbstractArray{T}, style=:auto)
    x_min = concrete_minimum(xs)
    x_max = concrete_maximum(xs)
    x_min = @compat Float64(@compat Float32(x_min))
    x_max = @compat Float64(@compat Float32(x_max))

    if !isfinite(x_min) || !isfinite(x_max)
        error("At least one finite value must be provided to formatter.")
    end

    if style == :auto
        if x_max != x_min && abs(log10(x_max - x_min)) > 4
            style = :scientific
        else
            style = :plain
        end
    end

    if style == :plain
        precision = plain_precision_heuristic(xs)
        return String[format_fixed(x, precision) for x in xs]
    elseif style == :scientific
        precision = scientific_precision_heuristic(xs)
        return String[format_fixed_scientific(x, precision, false)
                      for x in xs]
    elseif style == :engineering
        precision = scientific_precision_heuristic(xs)
        return String[format_fixed_scientific(x, precision, true)
                      for x in xs]
    else
        error("$(style) is not a recongnized number format")
    end
end


# Print a floating point number at fixed precision. Pretty much equivalent to
# @sprintf("%0.$(precision)f", x), without the macro issues.
function format_fixed(x::FloatingPoint, precision::Integer)
    @assert precision >= 0

    if x == Inf
        return "∞"
    elseif x == -Inf
        return "-∞"
    elseif isnan(x)
        return "NaN"
    end

    len, point, neg, digits = grisu(x, Base.Grisu.FIXED, precision)

    buf = IOBuffer()
    if x < 0
        print(buf, '-')
    end

    for c in digits[1:min(point, len)]
        print(buf, convert(Char, c))
    end

    if point > len
        for _ in len:point-1
            print(buf, '0')
        end
    elseif point < len
        if point <= 0
            print(buf, '0')
        end
        print(buf, '.')
        if point < 0
            for _ in 1:-point
                print(buf, '0')
            end
            for c in digits[1:len]
                print(buf, convert(Char, c))
            end
        else
            for c in digits[point+1:len]
                print(buf, convert(Char, c))
            end
        end
    end

    trailing_zeros = precision - max(0, len - point)
    if trailing_zeros > 0 && point >= len
        print(buf, '.')
    end

    for _ in 1:trailing_zeros
        print(buf, '0')
    end

    takebuf_string(buf)
end

const superscript_numerals = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']

# Print a floating point number in scientific notation at fixed precision. Sort of equivalent
# to @sprintf("%0.$(precision)e", x), but prettier printing.
function format_fixed_scientific(x::FloatingPoint, precision::Integer,
                                 engineering::Bool)
    if x == 0.0
        return "0"
    elseif x == Inf
        return "∞"
    elseif x == -Inf
        return "-∞"
    elseif isnan(x)
        return "NaN"
    end

    mag = floor(Int, log10(abs(x)))
    if mag < 0
        grisu_precision = precision + abs(round(Int, mag))
    else
        grisu_precision = precision
    end

    len, point, neg, digits = grisu((x / 10.0^mag), Base.Grisu.FIXED, grisu_precision)
    point += mag

    @assert len > 0

    buf = IOBuffer()
    if x < 0
        print(buf, '-')
    end

    print(buf, convert(Char, digits[1]))
    nextdigit = 2
    if engineering
        while (point - 1) % 3 != 0
            if nextdigit <= len
                print(buf, convert(Char, digits[nextdigit]))
            else
                print(buf, '0')
            end
            nextdigit += 1
            point -= 1
        end
    end

    if precision > 1
        print(buf, '.')
    end

    for i in nextdigit:len
        print(buf, convert(Char, digits[i]))
    end

    for i in (len+1):precision
        print(buf, '0')
    end

    print(buf, "×10")
    for c in string(point - 1)
        if '0' <= c <= '9'
            print(buf, superscript_numerals[c - '0' + 1])
        elseif c == '-'
            print(buf, '⁻')
        end
    end

    return takebuf_string(buf)
end



if VERSION >= v"0.4-dev"
    function showoff{T <: Union(Date, DateTime)}(ds::AbstractArray{T}, style=:none)
        years = Set()
        months = Set()
        days = Set()
        hours = Set()
        minutes = Set()
        seconds = Set()
        for d in ds
            push!(years, Dates.year(d))
            push!(months, Dates.month(d))
            push!(days, Dates.day(d))
            push!(hours, Dates.hour(d))
            push!(minutes, Dates.minute(d))
            push!(seconds, Dates.second(d))
        end
        all_same_year         = length(years)   == 1
        all_one_month         = length(months)  == 1 && 1 in months
        all_one_day           = length(days)    == 1 && 1 in days
        all_zero_hour         = length(hours)   == 1 && 0 in hours
        all_zero_minute       = length(minutes) == 1 && 0 in minutes
        all_zero_seconds      = length(minutes) == 1 && 0 in minutes
        all_zero_milliseconds = length(minutes) == 1 && 0 in minutes

        # first label format
        label_months = false
        label_days = false
        f1 = "u d, yyyy"
        f2 = ""
        if !all_zero_seconds
            f2 = "HH:MM:SS.sss"
        elseif !all_zero_seconds
            f2 = "HH:MM:SS"
        elseif !all_zero_hour || !all_zero_minute
            f2 = "HH:MM"
        else
            if !all_one_day
                first_label_format = "u d yyyy"
            elseif !all_one_month
                first_label_format = "u yyyy"
            elseif !all_one_day
                first_label_format = "yyyy"
            end
        end
        if f2 != ""
            first_label_format = string(f1, " ", f2)
        else
            first_label_format = f1
        end

        labels = Array(String, length(ds))
        labels[1] = Dates.format(ds[1], first_label_format)
        d_last = ds[1]
        for (i, d) in enumerate(ds[2:end])
            if Dates.year(d) != Dates.year(d_last)
                if all_one_day && all_one_month
                    f1 = "yyyy"
                elseif all_one_day && !all_one_month
                    f1 = "u yyyy"
                else
                    f1 = "u d, yyyy"
                end
            elseif Dates.month(d) != Dates.month(d_last)
                f1 = all_one_day ? "u" : "u d"
            elseif Dates.day(d) != Dates.day(d_last)
                f1 = "d"
            else
                f1 = ""
            end

            if f2 != ""
                f = string(f1, " ", f2)
            elseif f1 != ""
                f = f1
            else
                f = first_label_format
            end

            labels[i+1] = Dates.format(d, f)
            d_last = d
        end

        return labels
    end
end


end # module
