# Diagnostic for the step-3 plan: tier S's passes with the erased batches (crossing per batch) against the same
# batches typed (upstream's tuple path through apply_comp!), each pass called from a function, not from globals.
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
typed(b) = (ND.ComponentBatch(ND.dispatchT(b), b.indices, b.compf, b.compg, b.ff,
            ND.BatchStride(b.statestride.first, b.statestride.strides), ND.BatchStride(b.pstride.first, b.pstride.strides),
            ND.BatchStride(b.inbufstride.first, b.inbufstride.strides), ND.BatchStride(b.outbufstride.first, b.outbufstride.strides),
            ND.BatchStride(b.extbufstride.first, b.extbufstride.strides)),)
pass(ex, fg, filt, bs, inb, du, u, o, p) = ND.process_batches!(ex, fg, filt, bs, inb, (du, u, o, p, T0))
for (name, bs, fg, filt, inb) in (("vertex :g", vb, Val(:g), !ND.hasff, (nothing, nothing)), ("edge :fg", eb, Val(:fg), ND.hasff, (gbuf, ext)),
                                  ("vertex :f", vb, Val(:f), !ND.hasff, (agg, ext)))
    tb = typed(bs[1])
    e() = pass(ex, fg, filt, bs, inb, du, u, o, p); t() = pass(ex, fg, filt, tb, inb, du, u, o, p)
    @printf("%-10s erased ns=%.0f allocs=%d | typed ns=%.0f allocs=%d   (%s)\n", name, tm(e), @allocations(e()), tm(t), @allocations(t()),
            typeof(tb[1].statestride).parameters[1])
end
