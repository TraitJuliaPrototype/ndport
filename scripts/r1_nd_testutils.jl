# R1 (E-236): nd_testutils.jl for setting PT; the two changed lines are marked R1.
# NetworkDynamics 1.3.0's test/testutils.jl (upstream), without CUDA: 'using CUDA, Adapt' and the
# 'if CUDA.functional() … end' block (lines 70–89) removed; skipped anyway without a GPU (the traits plan §2.5).
using NetworkDynamics: iscudacompatible, NaiveAggregator

"""
Test utility, which rebuilds the Network with all different execution styles and compares the
results of the coreloop.
"""
function test_execution_styles(prob)
    styles = [KAExecution{true}(),
              KAExecution{false}(),
              SequentialExecution{true}(),
              SequentialExecution{false}(),
              PolyesterExecution{true}(),
              PolyesterExecution{false}(),
              ThreadedExecution{true}(),
              ThreadedExecution{false}()]
    unmatchedstyles = filter(subtypes(NetworkDynamics.ExecutionStyle)) do abstractstyle
        !any(s -> s isa abstractstyle, styles)
    end
    @assert isempty(unmatchedstyles) "Some ExecutionStyle won't be tested: $unmatchedstyles"

    aggregators = [NaiveAggregator,
                   KAAggregator,
                   SequentialAggregator,
                   PolyesterAggregator,
                   ThreadedAggregator,
                   SparseAggregator]
    unmatchedaggregators = filter(subtypes(NetworkDynamics.Aggregator)) do abstractaggregator
        !any(s -> s <: abstractaggregator, aggregators)
    end
    @assert isempty(unmatchedaggregators) "Some AggrgationStyle won't be tested: $unmatchedaggregators"

    @assert prob isa ODEProblem "test_execution_styles only works for ODEProblems"

    u = copy(prob.u0)
    du = zeros(eltype(u), length(u))
    t = 0.0
    p = prob.p === nothing ? nothing : copy(prob.p)   # R1: TDE's absent parameters are `nothing` (SciML: NullParameters)
    nw = Main.R1_FN[prob]                              # R1 stand-in for `prob.f.f`: recorded by r1_odeproblem
    nw(du, u, p, t)
    @test u==prob.u0
    @test p==prob.p

    exsaggs = [(ex, agg) for ex in styles for agg in aggregators]

    @testset "Test Execution Styles and Aggregators" begin
        for (execution, aggregator) in exsaggs
            _nw = Network(nw; execution, aggregator=aggregator(nw.layer.aggregator.f))
            _du = zeros(eltype(u), length(u))
            try
                _nw(_du, u, p, t)
            catch e
                # XXX: fix for https://github.com/JuliaLang/julia/issues/55075
                if e isa MethodError && e.f == Base.elsize && execution isa KAExecution
                    @test_broken false
                    continue
                end
                println("Error in $execution with $aggregator: $e")
                @test false
                continue
            end
            issame = isapprox(_du, du; atol=1e-10)
            if !issame
                println("$execution with $aggregator lead to different results: extrema(Δ) = $(extrema(_du - du))")
            end
            @test issame
        end

    end

    @testset "Test sparsity pattern" begin
        try
            get_jac_prototype(nw) # throws if the jacobian prototyp mismatches the forward diff one
            @test true
        catch
            @test false
        end
    end
    nothing
end
