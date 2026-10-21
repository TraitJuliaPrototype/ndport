# P3 diagnostic: where the wrapped NetworkDynamics spends a steady-state solve. Builds the workload's
# network (steps a–c), solves once with Tsit5 (compiles), then profiles the dynamic calls of a second
# solve (JULIA_FACTS_DISPATCH_PROFILE=1) and times one right-hand-side call.
#     JULIA_FACTS_DISPATCH_PROFILE=1 julia --project=env_p3 scripts/p3_hot.jl
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
using CairoMakie, GraphMakie, Observables
include(joinpath(@__DIR__, "workload_steps.jl"))
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
u = copy(NDW.uflat(c.s)); p = copy(NDW.pflat(c.s)); du = similar(u)
nw(du, u, p, 0.0)
t = @elapsed for _ in 1:1000; nw(du, u, p, 0.0); end
println("rhs: ", round(t * 1e6, digits = 1), " µs per call; allocs ", @allocated(nw(du, u, p, 0.0)))
prob = ODEProblem(nw, c.s, (0.0, 6.0))
solve(prob, Tsit5(); NDW.SOLVE_KW...)
println("solve: ", @elapsed(solve(prob, Tsit5(); NDW.SOLVE_KW...)), " s")
haskey(ENV, "JULIA_FACTS_DISPATCH_PROFILE") && ccall(:jl_facts_dispatch_profile_reset, Cvoid, ())
for _ in 1:100; nw(du, u, p, 0.0); end
haskey(ENV, "JULIA_FACTS_DISPATCH_PROFILE") && ccall(:jl_facts_dispatch_profile_print, Cvoid, ())
exit(0)
