# The workload's driver (the P1 plan §2.3): the loads timed in groups, then the passes
#   first   (a–g, swing equations)       the time to first X
#   again   (a–g, the same types)         the steady state
#   params  (d–g: the problem remade with a new damping γ)   the control: new values, no new types
#   changed (a–g, swing2!)                new equations: a new component function type
# Each step's first call is timed whole (as TraitDifferentialEquations' rows.jl `@first`).
# Prints `L <group> <s>`, `T <pass> <step> <ms> compile <ms> recompile <ms> gc <ms>`, and the digests.
#     julia --project=env_upstream scripts/workload.jl            (from ndport/)
# NDW_PASSES=first,params,changed (default: all; `again` always runs). NDW_DIAG=1: the attribution run
# (scripts/diag.jl; new CodeInstances per step by module and owner; its times are not measurements).
const T0 = time_ns()
const WITH_TW = get(ENV, "NDW_TRAITWORLD", "0") == "1"
macro load(name, ex)
    quote
        local t = @elapsed $(esc(ex))
        println("L ", $name, " ", round(t; digits = 2)); flush(stdout)
    end
end
WITH_TW && @load "TraitWorld" (@eval using TraitWorld)
@load "Graphs,NetworkDynamics" (@eval using Graphs, NetworkDynamics)
@load "solvers" (@eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface)
@load "CairoMakie,GraphMakie,Observables" (@eval using CairoMakie, GraphMakie, Observables)
@load "steps" include(joinpath(@__DIR__, "workload_steps.jl"))
mkpath(NDW.OUT)
CairoMakie.activate!(type = "png")

function timed(name, f)
    c0 = Base.cumulative_compile_time_ns(); g0 = Base.gc_num(); t0 = time_ns()
    r = Base.invokelatest(f)
    t = (time_ns() - t0) / 1e6
    c1 = Base.cumulative_compile_time_ns()
    gc = Base.GC_Diff(Base.gc_num(), g0).total_time / 1e6
    println("T ", NDW.PASS[], " ", name, " ", round(t; digits = 1), " compile ", round((c1[1] - c0[1]) / 1e6; digits = 1),
            " recompile ", round((c1[2] - c0[2]) / 1e6; digits = 1), " gc ", round(gc; digits = 1))
    flush(stdout)
    r
end

const DIAG = get(ENV, "NDW_DIAG", "0") == "1"
DIAG && include(joinpath(@__DIR__, "diag.jl"))
const step_timer = DIAG ? Base.invokelatest(NDWDiag.wrap, timed, NDW.PASS) : timed
const PASSES = split(get(ENV, "NDW_PASSES", "first,again,params,changed"), ",")
Base.cumulative_compile_timing(true)
"first" in PASSES && NDW.run_pass(step_timer, "first", :swing)
nw, prob = NDW.run_pass(step_timer, "again", :swing)
"params" in PASSES && NDW.run_params(step_timer, nw, prob)
"changed" in PASSES && NDW.run_pass(step_timer, "changed", :swing2)
println("W total ", round((time_ns() - T0) / 1e9; digits = 1))
