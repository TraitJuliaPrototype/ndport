# R1 (E-236): NetworkDynamics' test subset in setting PT (env_ports): nd_tests.jl with the test files'
# `using OrdinaryDiffEq*` read as `using TraitDifferentialEquations` (TDE's Tsit5 and Rodas5), and no SciMLBase.
#     julia -t 2 --project=env_ports scripts/r1_nd_tests.jl
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
include(joinpath(@__DIR__, "r1_nd_testutils.jl"))   # R1: nd_testutils.jl for the ports

"""
R1: the test files read for the ports: their solver packages as TDE's umbrella; `ODEProblem(f, …)` recorded
(`r1_odeproblem`), so that `test_execution_styles` finds the network without `prob.f.f` (stand-in: TDE's
problem gives no way back to its function); `ODEFunction(f)` with `f`'s result dropped (`r1_odefunction`;
stand-in: TDE's in-place functions must return `nothing`). Each stand-in prints `R1T <file> STANDIN …` once.
"""
function r1_ports(ex)
    ex isa Expr || return ex
    if ex.head === :using && any(a -> a isa Expr && !isempty(a.args) && a.args[1] isa Symbol && startswith(string(a.args[1]), "OrdinaryDiffEq"), ex.args)
        return :(using TraitDifferentialEquations)
    end
    if ex.head === :call && ex.args[1] === :Rodas4
        return :(Main.r1_rodas4())
    end
    if ex.head === :call && ex.args[1] === :solve
        return Expr(:call, :(Main.r1_solve), map(r1_ports, ex.args[2:end])...)
    elseif ex.head === :call && ex.args[1] === :NWState
        return Expr(:call, :(Main.r1_nwstate), map(r1_ports, ex.args[2:end])...)
    elseif ex.head === :call && length(ex.args) == 3 && ex.args[3] isa Expr && ex.args[3].head === :kw && ex.args[3].args[1] === :idxs
        return Expr(:call, :(Main.r1_sol_idxs), r1_ports(ex.args[1]), r1_ports(ex.args[2]), r1_ports(ex.args[3].args[2]))
    end
    if ex.head === :call && ex.args[1] === :ODEProblem
        return Expr(:call, :(Main.r1_odeproblem), map(r1_ports, ex.args[2:end])...)
    elseif ex.head === :call && ex.args[1] === :ODEFunction
        return Expr(:call, :(Main.r1_odefunction), map(r1_ports, ex.args[2:end])...)
    end
    return Expr(ex.head, map(r1_ports, ex.args)...)
end
const R1_FN = IdDict{Any,Any}()
const R1_SEEN = Set{String}()
r1_note(what) = what in R1_SEEN || (push!(R1_SEEN, what); println("R1T STANDIN ", what))
r1_rodas4() = (r1_note("Rodas4() read as Rodas5() (TDE has Rodas5 only)"); Rodas5())
"R1 stand-in: SciML's `ODEFunction` is callable, TDE's is not; the test files call it."
struct R1Fn{F}
    odef::F
end
(r::R1Fn)(du, u, p, t) = r.odef.f(du, u, p, t)
function r1_odeproblem(f, args...; kw...)
    f isa R1Fn && (f = f.odef)
    prob = ODEProblem(f, args...; kw...)
    R1_FN[prob] = f isa TraitDifferentialEquations.ODEFunction ? f.f : f
    prob
end
"R1 stand-in: TDE's solution gives no way back to the network (`extract_nw(sol)`): recorded at `solve`."
const R1_NW = IdDict{Any,Any}()
function r1_solve(prob, args...; kw...)
    sol = solve(prob, args...; kw...)
    haskey(R1_FN, prob) && R1_FN[prob] isa NetworkDynamics.Network && (R1_NW[sol] = R1_FN[prob])
    sol
end
function r1_nwstate(x, args...; kw...)
    if haskey(R1_NW, x)
        r1_note("NWState(sol, …): the network from the recorded solve (TDE: no way back from the solution)")
        return NWState(R1_NW[x], args...; kw...)
    end
    NWState(x, args...; kw...)
end
function r1_sol_idxs(sol, t, idxs)
    r1_note("sol(t; idxs): NetworkDynamics' own indexing over NWState(nw, sol(t)) (TDE's solution takes no idxs)")
    NWState(R1_NW[sol], sol(t))[idxs]
end
function r1_odefunction(f; kw...)
    r1_note("ODEFunction(f): f's result dropped (TDE: in-place functions return nothing)")
    r1_note("ODEFunction(f) callable through a wrapper (TDE's ODEFunction is not callable)")
    R1Fn(ODEFunction((du, u, p, t) -> (f(du, u, p, t); nothing); kw...))
end
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
