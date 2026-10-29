# R5 (E-246): why PT's Tsit5 values at TIMES are farther from the tight run than U′'s. Steps a–c of the workload's
# variant, then a transient without callbacks (vertex 1's ω kicked to 0.5): Tsit5 at the workload's tolerances
# against Tsit5 at 1e-12, at TIMES, (1) by saveat, (2) by saveat with tstops = TIMES (steps ending at TIMES: no
# interpolation), (3) dense output read at TIMES; the accepted and rejected steps.
#     NDW_API=ports NDW_STACK=<ports|upstream> julia --project=<env_r5|env_upstream> scripts/r5_probe_tsit5.jl
include(joinpath(@__DIR__, "workload_steps.jl"))
using .NDW, NetworkDynamics, Graphs
const ON_PORTS = NDW.ON_PORTS
@static if ON_PORTS
    using TraitDifferentialEquations
    steps(s) = (s.naccept, s.nreject)
else
    using OrdinaryDiffEqTsit5
    steps(s) = (s.stats.naccept, s.stats.nreject)
end
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
s0 = NWState(nw); s0.v[1, :ω] = 0.5
prob = ODEProblem(nw, s0, (0.0, 6.0))
T = NDW.TIMES
ref = solve(prob, Tsit5(); abstol = 1e-12, reltol = 1e-12, saveat = T, tstops = T)
refu = [ref.u[findfirst(==(t), ref.t)] for t in T]
err(us) = maximum(maximum(abs, u .- r) for (u, r) in zip(us, refu))
s1 = solve(prob, Tsit5(); NDW.SOLVE_KW..., saveat = T)
s2 = solve(prob, Tsit5(); NDW.SOLVE_KW..., saveat = T, tstops = T)
s3 = solve(prob, Tsit5(); NDW.SOLVE_KW...)
println("PROBE stack=", ON_PORTS ? "ports" : "upstream", " saveat err=", err([s1.u[findfirst(==(t), s1.t)] for t in T]), " steps=", steps(s1))
println("PROBE stack=", ON_PORTS ? "ports" : "upstream", " saveat+tstops err=", err([s2.u[findfirst(==(t), s2.t)] for t in T]), " steps=", steps(s2))
println("PROBE stack=", ON_PORTS ? "ports" : "upstream", " dense err=", err([s3(t) for t in T]), " steps=", steps(s3))
