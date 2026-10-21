# NetworkDynamics' test subset (the traits plan §2.5, E-152): the files that load without
# ModelingToolkit, Chairmarks, Symbolics or a GPU. Each file runs in a module of its own, as
# Testfiles' @testfile does; `test_execution_styles` comes from nd_testutils.jl (upstream's, without CUDA).
#
#     julia --project=env_ndtest_u  scripts/nd_tests.jl     (the clones at upstream)
#     julia --project=env_ndtest_p4 scripts/nd_tests.jl     (the P4 worktree; depot-p4)
#
# Prints `TEST <file> pass=… fail=… error=… broken=…` per file, and each failure as Test reports it.
using Test, NetworkDynamics, SciMLBase, InteractiveUtils
using NetworkDynamics: iscudacompatible, NaiveAggregator
include(joinpath(@__DIR__, "nd_testutils.jl"))

const TESTDIR = joinpath(pkgdir(NetworkDynamics), "test")
const FILES = ["massmatrix_test.jl", "doctor_test.jl", "diffusion_test.jl", "inhomogeneous_test.jl"]
println("# nd_tests threads=", Threads.nthreads(), " nd=", pkgdir(NetworkDynamics))

function counts(ts)
    c = Test.get_test_counts(ts)
    (; pass = c.passes + c.cumulative_passes, fail = c.fails + c.cumulative_fails,
       error = c.errors + c.cumulative_errors, broken = c.broken + c.cumulative_broken)
end

# collects the files' testsets, so that a failing file does not stop the run
mutable struct Collector <: Test.AbstractTestSet
    description::String
    results::Vector{Any}
end
Collector(desc; kw...) = Collector(desc, Any[])
Test.record(c::Collector, r) = (push!(c.results, r); r)
Test.finish(c::Collector) = c

top = @testset Collector "nd subset" begin
for f in FILES
    # massmatrix runs without the component check, as in upstream's runtests.jl
    NetworkDynamics.CHECK_COMPONENT[] = f != "massmatrix_test.jl"
    m = Module(Symbol(replace(f, ".jl" => "")))
    Core.eval(m, :(using Test))
    Core.eval(m, :(include(x) = Base.include($m, x)))
    t0 = time()
    @testset Test.DefaultTestSet "$f" begin
        Base.include(m, joinpath(TESTDIR, f))
    end
    println("# ", f, " s=", round(time() - t0; digits = 1))
end
end
for ts in top.results
    c = counts(ts)
    println("TEST ", ts.description, " pass=", c.pass, " fail=", c.fail, " error=", c.error, " broken=", c.broken)
end
NetworkDynamics.CHECK_COMPONENT[] = true
