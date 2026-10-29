# The workload's driver (the P1 plan §2.3): the loads timed in groups, then the passes
#   first   (a–g, swing equations)       the time to first X
#   again   (a–g, the same types)         the steady state
#   params  (d–g: the problem remade with a new damping γ)   the control: new values, no new types
#   changed (a–g, swing2!)                new equations: a new component function type
#   graphtype (a–g, swing!, the network on a Graphs.Test.GenericGraph; only when NDW_PASSES names it):
#                                         a graph type upstream refuses (the graph plan's G7, E-154). A step
#                                         that throws prints `D graphtype <step> error=<type>` and ends the pass.
#   usertype (a–g, a user's own types `Swing` and `Line` implementing VertexDynamics and EdgeDynamics, passed by
#             `dynamics = x`; the ports only, when NDW_PASSES names it; R6, E-247): the same digests as `first`.
# Each step's first call is timed whole (as TraitDifferentialEquations' rows.jl `@first`).
# Prints `L <group> <s>`, `T <pass> <step> <ms> compile <ms> recompile <ms> gc <ms>`, and the digests.
#     julia --project=env_upstream scripts/workload.jl            (from ndport/)
# NDW_ORDER=simfirst: the plotting packages load after the first pass's simulation (steps a–e).
# NDW_API=ports, NDW_STACK=ports: the variant for the trait ports and the stack it runs on (workload_steps.jl; R5, E-246).
# NDW_PASSES=first,params,changed (default: first,again,params,changed; `again` always runs; `graphtype` added on request). NDW_DIAG=1: the attribution run
# (scripts/diag.jl; new CodeInstances per step by module and owner; its times are not measurements).
const T0 = time_ns()
const WITH_TW = get(ENV, "NDW_TRAITWORLD", "0") == "1"
macro load(name, ex)
    quote
        local t = @elapsed $(esc(ex))
        println("L ", $name, " ", round(t; digits = 2)); flush(stdout)
    end
end
const ORDER = get(ENV, "NDW_ORDER", "default")   # `simfirst`: the plotting packages load after the first simulation (P3's order B)
WITH_TW && @load "TraitWorld" (@eval using TraitWorld)
@load "Graphs,NetworkDynamics" (@eval using Graphs, NetworkDynamics)
const ON_PORTS = get(ENV, "NDW_STACK", "upstream") == "ports"   # R5 (E-246): NetworkDynamics on the trait ports
if ON_PORTS
    @load "solvers" (@eval using TraitDifferentialEquations, SymbolicIndexingInterface)
    load_plotting() = (@load "MakieCompat,GraphMakie,Observables" (@eval using MakieCompat, GraphMakie, Observables);
                       @load "plot steps" Base.include(NDW, joinpath(@__DIR__, "workload_plot.jl")))
else
@load "solvers" (@eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface)
load_plotting() = (@load "CairoMakie,GraphMakie,Observables" (@eval using CairoMakie, GraphMakie, Observables);
                   @load "plot steps" Base.include(NDW, joinpath(@__DIR__, "workload_plot.jl"));
                   @eval CairoMakie.activate!(type = "png"))
end
const AS_TRAIT_MODULE = get(ENV, "NDW_W", "0") == "1"      # setting W: the workload's own module is a trait module
if AS_TRAIT_MODULE
    @load "steps" Core.eval(Main, let ex = Meta.parseall(read(joinpath(@__DIR__, "workload_steps.jl"), String))
        i = findfirst(a -> a isa Expr && a.head === :module, ex.args)
        Expr(:macrocall, GlobalRef(TraitWorld, Symbol("@trait_module")), LineNumberNode(1, :workload_steps), ex.args[i])
    end)
else
    @load "steps" include(joinpath(@__DIR__, "workload_steps.jl"))
end
mkpath(NDW.OUT)
ORDER == "simfirst" || load_plotting()

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
(DIAG || ORDER == "simfirst") && include(joinpath(@__DIR__, "diag.jl"))
const step_timer = DIAG ? Base.invokelatest(NDWDiag.wrap, timed, NDW.PASS) : timed
const PASSES = split(get(ENV, "NDW_PASSES", "first,again,params,changed"), ",")
Base.cumulative_compile_timing(true)
if ORDER == "simfirst"
    st = NDW.run_sim(step_timer, "first", :swing)
    v0, _ = Base.invokelatest(NDWDiag.snapshot)            # what the plotting load may discard (outside the timed windows)
    t = @elapsed load_plotting()
    r = Base.invokelatest(NDWDiag.lost, v0)
    println("G plotting-load ", round(t; digits = 2), " s lost=", r.n, "/", r.of, " owners: ", r.owners, " | modules: ", r.modules)
    Base.invokelatest(NDW.run_plot, step_timer, st)
else
    "first" in PASSES && NDW.run_pass(step_timer, "first", :swing)
end
nw, prob = NDW.run_pass(step_timer, "again", :swing)
"params" in PASSES && NDW.run_params(step_timer, nw, prob)
"changed" in PASSES && NDW.run_pass(step_timer, "changed", :swing2)
if "graphtype" in PASSES
    gt_step = Ref("a")
    gt_timer(name, f) = (gt_step[] = name; step_timer(name, f))
    try
        NDW.run_pass(gt_timer, "graphtype", :swing; graph = Val(:generic))
    catch err
        println("D graphtype ", gt_step[], " error=", nameof(typeof(err))); flush(stdout)
    end
end
if "usertype" in PASSES      # R6 (E-247): a user's own types `Swing`, `Line` (workload_types.jl), the same digests as `first`
    ut_step = Ref("a")
    ut_timer(name, f) = (ut_step[] = name; step_timer(name, f))
    try
        NDW.run_pass(ut_timer, "usertype", :swing_type)
    catch err
        println("D usertype ", ut_step[], " error=", nameof(typeof(err))); flush(stdout)
        showerror(stdout, err, catch_backtrace()); println(); flush(stdout)
    end
end
println("W total ", round((time_ns() - T0) / 1e9; digits = 1))
