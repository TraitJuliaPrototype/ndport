# R3 (E-242): r2_nd_tests.jl after TDE's R3 items: `sol(t; idxs)` is NetworkDynamics' own method on TDE's solution
# (no rewrite); the in-place function that returned its array is adapted at the source (diffusion_test.jl, marked
# `# ports`; open issue 120, decided). Kept: `Rodas4` as `Rodas5`; the harness' absent parameters (r2_nd_testutils.jl).
#     julia -t 2 --project=env_ports scripts/r3_nd_tests.jl
#
# The R2 header: R2 (E-239): NetworkDynamics' test subset in setting PT after TDE's R2 items: r1_nd_tests.jl with the stand-ins
# that TDE's R2 items make unneeded removed (the network back from a problem or a solution: `extract_nw`;
# `NWState(sol, t)`; a callable `ODEFunction`). Kept: `Rodas4` as `Rodas5`, an in-place function's result
# dropped (open issue 120), `sol(t; idxs)` by NetworkDynamics' own indexing (open issue 118).
#     julia -t 2 --project=env_ports scripts/r2_nd_tests.jl
#
# The original header: NetworkDynamics' test subset (the traits plan §2.5, E-152): the files that load without
# ModelingToolkit, Chairmarks, Symbolics or a GPU. Each file runs in a module of its own, as
# Testfiles' @testfile does; `test_execution_styles` comes from nd_testutils.jl (upstream's, without CUDA).
#
#     julia --project=env_ndtest_u  scripts/nd_tests.jl     (the clones at upstream)
#     julia --project=env_ndtest_p4 scripts/nd_tests.jl     (the P4 worktree; depot-p4)
#
# Prints `TEST <file> pass=… fail=… error=… broken=…` per file, and each failure as Test reports it.
using Test, NetworkDynamics, TraitDifferentialEquations, InteractiveUtils
using NetworkDynamics: iscudacompatible, NaiveAggregator
include(joinpath(@__DIR__, "r2_nd_testutils.jl"))   # R2: nd_testutils.jl for the ports

"""
R2: the test files read for the ports: their solver packages as TDE's umbrella; `Rodas4` as `Rodas5`; `ODEFunction(f)`
with `f`'s result dropped (`r2_odefunction`; open issue 120); `sol(t; idxs)` by NetworkDynamics' own indexing
(`r2_sol_idxs`; open issue 118). Each stand-in prints `R1T STANDIN …` once.
"""
function r1_ports(ex)
    ex isa Expr || return ex
    if ex.head === :using && any(a -> a isa Expr && !isempty(a.args) && a.args[1] isa Symbol && startswith(string(a.args[1]), "OrdinaryDiffEq"), ex.args)
        return :(using TraitDifferentialEquations)
    end
    if ex.head === :call && ex.args[1] === :Rodas4
        return :(Main.r1_rodas4())
    end
    return Expr(ex.head, map(r1_ports, ex.args)...)
end
const R1_SEEN = Set{String}()
r1_note(what) = what in R1_SEEN || (push!(R1_SEEN, what); println("R1T STANDIN ", what))
r1_rodas4() = (r1_note("Rodas4() read as Rodas5() (TDE has Rodas5 only)"); Rodas5())
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
        Base.include(r1_ports, m, joinpath(TESTDIR, f))
    end
    println("# ", f, " s=", round(time() - t0; digits = 1))
end
end
for ts in top.results
    c = counts(ts)
    println("TEST ", ts.description, " pass=", c.pass, " fail=", c.fail, " error=", c.error, " broken=", c.broken)
end
NetworkDynamics.CHECK_COMPONENT[] = true
