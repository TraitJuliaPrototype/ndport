# Diagnostic for the step-3 plan: the crossing alone (an empty batch) against a full batch, per pass.
using NetworkDynamics, Graphs, Printf
const ND = NetworkDynamics
include("/home/hellmann/Repos/julia-trait-bound/ndport/scripts/rhs_check_nets.jl")
nw = tierS(:swing)
u, p = fixed_u(nw), fixed_p(nw); du = zeros(length(u))
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
vb = nw.vertexbatches; eb = nw.layer.edgebatches
o, agg, ext = ND.get_buffers(nw, u, p, T0)
gbuf = ND.get_gbuf(nw.gbufprovider, o); ND.gather!(nw.gbufprovider, gbuf, o)
ex = SequentialExecution{true}()
emptied(b) = [ND.ComponentBatch(ND.dispatchT(b), Int[], b.compf, b.compg, b.ff, b.statestride, b.pstride, b.inbufstride,
                               b.outbufstride, b.extbufstride; kept = true, erased = true)]
for (name, bs, fg, inb) in (("vertex :f", vb, Val(:f), (agg, ext)), ("vertex :g", vb, Val(:g), (nothing, nothing)), ("edge :fg", eb, Val(:fg), (gbuf, ext)))
    args = Ref((ex, fg, inb, du, u, o, p, T0))
    be = emptied(bs[1])
    isedge = ND.dispatchT(bs[1]) === EdgeModel
    cross(v) = isedge ? ND.run_edge_batch!(ND.compiled_for(v[1].model), v, 1, args) : ND.run_vertex_batch!(ND.compiled_for(v[1].model), v, 1, args)
    @printf("%-10s full batch (%d) ns=%.0f allocs=%d | empty batch ns=%.0f allocs=%d\n", name, length(bs[1]),
            tm(() -> cross(bs)), @allocations(cross(bs)), tm(() -> cross(be)), @allocations(cross(be)))
end
cfk(v) = ND.compiled_for(v[1].model)
@printf("compiled_for(kept) ns=%.0f allocs=%d\n", tm(() -> cfk(vb)), @allocations(cfk(vb)))
mkref() = Ref((ex, Val(:f), (agg, ext), du, u, o, p, T0))
@printf("Ref of the pass's arguments ns=%.0f allocs=%d\n", tm(mkref), @allocations(mkref()))
