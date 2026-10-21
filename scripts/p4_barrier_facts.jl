# The crossing from facts code (a caller defined in ND by Core.eval) against plain code (Main). Diagnostic.
#     julia --project=env_p4 scripts/p4_barrier_facts.jl
using NetworkDynamics, Graphs, Printf
const ND = NetworkDynamics
include(joinpath(@__DIR__, "rhs_check_nets.jl"))
nw = tierS(:swing)
u, p = fixed_u(nw), fixed_p(nw); du = zeros(length(u))
vb = nw.vertexbatches
o, agg, ext = ND.get_buffers(nw, u, p, T0)
args = Ref((SequentialExecution{true}(), Val(:f), (agg, ext), du, u, o, p, T0))
function tm(f, n = 100_000)
    f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
Core.eval(ND, quote
    _t_cf(b) = compiled_for(b.model)
    _t_call(m, vb, args) = run_vertex_batch!(m, vb, 1, args)
    _t_both(vb, args) = run_vertex_batch!(compiled_for(vb[1].model), vb, 1, args)
    _t_both2(vb, args) = run_vertex_batch!(compiled_for(vb[1].model)::Kept{ComponentDynamics}, vb, 1, args)
end)
anym = Any[ND.compiled_for(vb[1].model)]
for (name, f) in (("facts cf", () -> ND._t_cf(vb[1])), ("plain cf", () -> ND.compiled_for(vb[1].model)),
                  ("facts call m::Any", () -> ND._t_call(anym[1], vb, args)),
                  ("facts cf+call", () -> ND._t_both(vb, args)), ("facts cf::Kept+call", () -> ND._t_both2(vb, args)))
    @printf("%-20s ns=%.0f allocs=%d\n", name, tm(f), @allocations(f()))
end
println(Base.return_types(ND._t_cf, (typeof(vb[1]),)))
