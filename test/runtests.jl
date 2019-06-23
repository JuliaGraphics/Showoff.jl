using Showoff
using Compat
using Compat.Test
using Compat.Dates

@testset "Internals" begin
    @test Showoff.@grisu_ccall(1, 2, 3) === nothing
    @test Showoff.grisu(1.0, Base.Grisu.SHORTEST, 2) == (1, 1, false, Base.Grisu.DIGITS)

    let x = [1.0, Inf, 2.0, NaN]
        @test Showoff.concrete_minimum(x) == 1.0
        @test Showoff.concrete_maximum(x) == 2.0
    end

    @test_throws ArgumentError Showoff.concrete_minimum([])
    @test_throws ArgumentError Showoff.concrete_maximum([])

    let x = [1.12345, 4.5678]
        @test Showoff.plain_precision_heuristic(x) == 5
        @test Showoff.scientific_precision_heuristic(x) == 6
    end
end

@testset "Formatting" begin
    @test Showoff.format_fixed(-10.0, 0) == "-10"
    @test Showoff.format_fixed(0.012345, 3) == "0.012"
    @test Showoff.format_fixed(Inf, 1) == "∞"
    @test Showoff.format_fixed(-Inf, 1) == "-∞"
    @test Showoff.format_fixed(NaN, 1) == "NaN"
    @test Showoff.format_fixed_scientific(0.0, 1, false) == "0"
    @test Showoff.format_fixed_scientific(Inf, 1, false) == "∞"
    @test Showoff.format_fixed_scientific(-Inf, 1, false) == "-∞"
    @test Showoff.format_fixed_scientific(NaN, 1, false) == "NaN"
    @test Showoff.format_fixed_scientific(0.012345678, 4, true) == "12.34568×10⁻³"
    @test Showoff.format_fixed_scientific(0.012345678, 4, false) == "1.234568×10⁻²"
    @test Showoff.format_fixed_scientific(-10.0, 4, false) == "-1.000×10¹"
end

@testset "Showoff" begin
    x = [1.12345, 4.5678]
    @test showoff(x) == ["1.12345", "4.56780"]
    @test showoff([0.0, 50000.0]) == ["0", "5×10⁴"]
    @test showoff(x, :plain) == ["1.12345", "4.56780"]
    @test showoff(x, :scientific) == ["1.12345×10⁰", "4.56780×10⁰"]
    @test showoff(x, :engineering) == ["1.12345×10⁰", "4.56780×10⁰"]
    @test showoff([DateTime("2017-04-11", "yyyy-mm-dd")]) == ["Apr 11, 2017"]
    @test showoff(["a", "b"]) == ["\"a\"", "\"b\""]
    @test showoff([1, 1e39]) == ["1×10⁰", "1×10³⁹"]
    @test_throws ArgumentError showoff(x, :nevergonnagiveyouup)
    @test_throws ArgumentError showoff([Inf, Inf, NaN])
end
