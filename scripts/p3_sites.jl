# P3 diagnostic: the run-time sites of the wrapped NetworkDynamics' right-hand side, by
# TraitWorld's `fully_typed` (the walk of verify_main: code compiled by facts, error paths left out).
#     julia --project=env_p3 scripts/p3_sites.jl
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
using CairoMakie, GraphMakie, Observables
include(joinpath(@__DIR__, "workload_steps.jl"))
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
u = copy(NDW.uflat(c.s)); p = copy(NDW.pflat(c.s)); du = similar(u)
nw(du, u, p, 0.0)
r = TraitWorld.fully_typed(nw, (Vector{Float64}, Vector{Float64}, Vector{Float64}, Float64))
show(stdout, MIME"text/plain"(), r); println()
for h in r.sites
    println("SITE ", h.kind, " ", h.line, " :: ", h.callee, " ", h.argtypes, " in ", h.caller)
end
