# P3, run 3 (the pirate): after the first Rodas5P solve (its Jacobian runs the line function on
# ForwardDiff's duals), Main defines a more specific `sin` on duals: a pirate (Main owns neither `sin`
# nor `Dual`), correct in value. Strict mode off: followed; on: refused if code it would win in is
# protected. Prints `R <strict> defined=<accepted|error type> lost=<n>/<m> owners: … digest_d_equal=<bool>`,
# the error's first 600 characters, and the second solve's digest.
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
const ForwardDiff = NetworkDynamics.ForwardDiff
include(joinpath(@__DIR__, "workload_steps.jl"))
include(joinpath(@__DIR__, "diag.jl"))
const STRICT = get(ENV, "JULIA_TW_STRICT", "0") == "1" ? "on" : "off"
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
d1 = NDW.step_d(nw, c.s); NDW.digest_d(d1)
v0, _ = NDWDiag.snapshot()
defined = try
    @eval Base.sin(d::ForwardDiff.Dual{T, Float64, N}) where {T, N} = ForwardDiff.Dual{T}(sin(d.value), cos(d.value) * d.partials)
    "accepted"
catch e
    println("ERROR ", first(sprint(showerror, e), 600))
    string(typeof(e))
end
r = NDWDiag.lost(v0)
NDW.PASS[] = "after"
d2 = NDW.step_d(nw, c.s); NDW.digest_d(d2)
same = d1.sol.u == d2.sol.u && d1.rsol.u == d2.rsol.u
println("R strict=", STRICT, " defined=", defined, " lost=", r.n, "/", r.of, " owners: ", r.owners, " | modules: ", r.modules, " digest_d_equal=", same)
