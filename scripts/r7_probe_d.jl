# R7 (E-250): where step d's steady state goes, on either stack (NDW_STACK=ports: PT; else U′), NDW_API=ports.
# Not a measurement of record: one session, each solve warmed up once, then the minimum of 3 (`@timed`).
# Prints `PD <what> ms=<min> alloc=<MB> steps=<accepted> nf=<rhs calls>` for: the network alone (no callbacks), Tsit5 and
# Rodas5; with the workload's 40 continuous component callbacks and the preset trip (step d's problem), Tsit5 and Rodas5.
#     NDW_STACK=ports scripts/r5_run.sh probe-d-PT scripts/r7_probe_d.jl     (U′: env_upstream, see r7 README section)
ENV["NDW_API"] = "ports"
const PORTS = get(ENV, "NDW_STACK", "upstream") == "ports"
using Graphs, NetworkDynamics
PORTS ? (@eval using TraitDifferentialEquations) : (@eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock)
include(joinpath(@__DIR__, "workload_steps.jl"))
using .NDW: SOLVE_KW, SAVE_KW
nw = NDW.step_b(NDW.step_a(:swing)); c = NDW.step_c(nw)
d = NDW.step_d(nw, c.s)                                   # warms up the callbacks' path
nsteps(sol) = PORTS ? sol.naccept : sol.stats.naccept
nf(sol) = PORTS ? sol.nf : sol.stats.nf
function probe(what, mk, alg)
    solve(mk(), alg; SOLVE_KW..., SAVE_KW...)
    best = nothing
    for _ in 1:3
        r = @timed solve(mk(), alg; SOLVE_KW..., SAVE_KW...)
        (best === nothing || r.time < best.time) && (best = r)
    end
    sol = best.value
    println("PD ", what, " ms=", round(1000 * best.time; digits = 2), " alloc=", round(best.bytes / 2^20; digits = 2),
            " steps=", try nsteps(sol) catch; "?" end, " nf=", try nf(sol) catch; "?" end); flush(stdout)
end
plain = ODEProblem(NDW.step_b(NDW.step_a(:swing)), NWState(nw), (0.0, 6.0))   # a network without callbacks
probe("plain Tsit5", () -> remake(plain; p = copy(plain.p)), Tsit5())
probe("plain Rodas5", () -> remake(plain; p = copy(plain.p)), Rodas5())
probe("events Tsit5", () -> remake(d.prob; p = copy(d.prob.p)), Tsit5())
probe("events Rodas5", () -> remake(d.prob; p = copy(d.prob.p)), Rodas5())
exit(0)
