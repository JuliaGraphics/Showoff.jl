module Showoff

using Dates

if isdefined(Base, :Ryu)
    include("ryu.jl")
else
    include("grisu.jl")
end

export showoff

# suppress compile errors when there isn't a grisu_ccall macro
macro grisu_ccall(x, mode, ndigits)
    quote end
end

# Fallback
function showoff(xs::AbstractArray, style=:none)
    result = Vector{String}(undef, length(xs))
    buf = IOBuffer()
    for (i, x) in enumerate(xs)
        show(buf, x)
        result[i] = String(take!(buf))
    end

    return result
end


# Floating-point

function concrete_minimum(xs)
    if isempty(xs)
        throw(ArgumentError("argument must not be empty"))
    end

    x_min = first(xs)
    for x in xs
        if isa(x, AbstractFloat) && isfinite(x)
            x_min = x
            break
        end
    end

    for x in xs
        if isa(x, AbstractFloat) && isfinite(x) && x < x_min
            x_min = x
        end
    end
    return x_min
end


function concrete_maximum(xs)
    if isempty(xs)
        throw(ArgumentError("argument must not be empty"))
    end

    x_max = first(xs)
    for x in xs
        if isa(x, AbstractFloat) && isfinite(x)
            x_max = x
            break
        end
    end

    for x in xs
        if isa(x, AbstractFloat) && isfinite(x) && x > x_max
            x_max = x
        end
    end
    return x_max
end

function scientific_precision_heuristic(xs::AbstractArray{<:AbstractFloat})
    ys = [x == 0.0 ? 0.0 : round(10.0 ^ (z = log10(abs(Float64(x))); z - floor(z)); sigdigits=15)
          for x in xs if isfinite(x)]
    return plain_precision_heuristic(ys) + 1
end


function showoff(xs::AbstractArray{<:AbstractFloat}, style=:auto)
    x_min = concrete_minimum(xs)
    x_max = concrete_maximum(xs)
    x_min = Float64(x_min)
    x_max = Float64(x_max)

    if !isfinite(x_min) || !isfinite(x_max)
        return invoke(showoff,Tuple{AbstractArray,Symbol},xs,:none)
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
        throw(ArgumentError("$(style) is not a recongnized number format"))
    end
end

const superscript_numerals = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']

function showoff(ds::AbstractArray{T}, style=:none) where T<:Union{Date,DateTime}

    all_one_month    = all(d -> isone(Dates.month(d)), ds)    
    all_one_day      = all(d -> isone(Dates.day(d)), ds)
    all_zero_hour    = all(d -> iszero(Dates.hour(d)), ds)
    all_zero_minute  = all(d -> iszero(Dates.minute(d)), ds)
    all_zero_seconds = all(d -> iszero(Dates.second(d)), ds)
    all_zero_msec    = all(d -> iszero(Dates.millisecond(d)), ds)

    # time label format
    tformat = if !all_zero_msec
        "HH:MM:SS.sss"
    elseif !all_zero_seconds
        "HH:MM:SS"
    elseif !all_zero_hour || !all_zero_minute
        "HH:MM"
    else
        ""
    end

    # date label format
    dformat = if tformat != ""
        "u d, yyyy"
    elseif all_one_day && all_one_month
        "yyyy"
    elseif all_one_day && !all_one_month
        "u yyyy"
    else
        "u d, yyyy"
    end
    
    first_dtformat = tformat == "" ? dformat : string(dformat, " ", tformat)

    labels = Vector{String}(undef, length(ds))
    labels[1] = Dates.format(ds[1], first_dtformat)

    d_last = ds[1]
    for (i, d) in enumerate(ds[2:end])
        year_changed = Dates.year(d) != Dates.year(d_last)
        month_changed = Dates.month(d) != Dates.month(d_last)
        day_changed = Dates.day(d) != Dates.day(d_last)

        dformat = if year_changed && all_one_day && all_one_month
            "yyyy"
        elseif year_changed && all_one_day && !all_one_month
            "u yyyy"
        elseif year_changed 
            "u d, yyyy"
        elseif month_changed && all_one_day
            "u"
         elseif month_changed && !all_one_day
            "u d"
        elseif day_changed
            "d"
        else # same day, month, year
            "" 
        end

        dtformat = if tformat != "" && dformat != ""
            string(dformat, " ", tformat)
        elseif tformat == "" && dformat != ""
            dformat
        elseif tformat != "" && dformat == ""
            tformat
        else
            first_dtformat
        end

        labels[i+1] = Dates.format(d, dtformat)
        d_last = d
    end

    return labels
end

end # module
