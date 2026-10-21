# The barrier's cost in P4 (PB-4): allocations (count and bytes) of one right-hand side of tier S,
# and the time of its parts. Diagnostic, not a measurement round.
#     julia --project=env_p4 scripts/p4_barrier.jl
using NetworkDynamics, Graphs, Printf
const ND = NetworkDynamics
include(joinpath(@__DIR__, "rhs_check_nets.jl"))
nw = tierS(:swing)
u, p = fixed_u(nw), fixed_p(nw); du = zeros(length(u))
rhs(nw, du, u, p) = nw(du, u, p, T0)
rhs(nw, du, u, p); rhs(nw, du, u, p)
println("allocations=", @allocations(rhs(nw, du, u, p)), " bytes=", @allocated(rhs(nw, du, u, p)))
function tm(f, n = 100_000)
    f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
vb = nw.vertexbatches; eb = nw.layer.edgebatches
o, agg, ext = ND.get_buffers(nw, u, p, T0)
args = Ref((SequentialExecution{true}(), Val(:f), (agg, ext), du, u, o, p, T0))
cf(b) = ND.compiled_for(b.model)
@printf("rhs ns=%.0f\n", tm(() -> rhs(nw, du, u, p)))
@printf("compiled_for ns=%.0f allocs=%d\n", tm(() -> cf(vb[1])), @allocations(cf(vb[1])))
callv(vb, args) = ND.run_vertex_batch!(ND.compiled_for(vb[1].model), vb, 1, args)
callv(vb, args)
@printf("run_vertex_batch!(compiled_for) ns=%.0f allocs=%d\n", tm(() -> callv(vb, args)), @allocations(callv(vb, args)))
m = cf(vb[1])
callm(m, vb, args) = ND.run_vertex_batch!(m, vb, 1, args)
@printf("run_vertex_batch!(m held) ns=%.0f allocs=%d\n", tm(() -> callm(m, vb, args)), @allocations(callm(m, vb, args)))
pk(ex, vb, du, u, o, p) = ND.process_batches!(ex, Val(:f), ND.nofilt, vb, (agg, ext), (du, u, o, p, T0))
pk(SequentialExecution{true}(), vb, du, u, o, p)
@printf("process_batches!(vertex, :f) ns=%.0f allocs=%d\n", tm(() -> pk(SequentialExecution{true}(), vb, du, u, o, p)), @allocations(pk(SequentialExecution{true}(), vb, du, u, o, p)))
using TraitWorld: fully_typed
argT = (SequentialExecution{true}, Val{:f}, typeof(ND.nofilt), typeof(vb), typeof((agg, ext)), typeof((du, u, o, p, T0)))
show(stdout, MIME"text/plain"(), fully_typed(ND._process_kept!, argT)); println()
show(stdout, MIME"text/plain"(), fully_typed(ND.run_vertex_batch!, (typeof(m), typeof(vb), Int, typeof(args)))); println()
