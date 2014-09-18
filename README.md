# Showoff

[![Build Status](https://travis-ci.org/dcjones/Showoff.jl.svg?branch=master)](https://travis-ci.org/dcjones/Showoff.jl)


Showoff provides and interface for consistently formatting an array of n things,
e.g. numbers, dates, unitful values. ~~It's used~~ It will be used in Gadfly to
label axis and keys.

If you want your type to look nice when plotted, just define a `showoff`
function. Here's an example.

```julia
import Showoff

immutable Percent
    value::Float64
end

function Showoff.showoff(xs::AbstractArray{Percent})
    return [string(x, "%") for x in showoff([x.value for x in xs])]
end
```

When no specialized `showoff` is defined, it falls back on the `show` function.


