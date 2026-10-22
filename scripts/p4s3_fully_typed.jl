# E-166: fully_typed at the batch functions (plan §2.3): the run-time sites of _process_kept! and of the worker of
# run_vertex_batch!/run_edge_batch! for tier S's kept models, after S3-3. Diagnostic.
using NetworkDynamics, Graphs, Printf
const ND = NetworkDynamics
using TraitWorld: fully_typed
include(joinpath(@__DIR__, "rhs_check_nets.jl"))
nw = tierS(:swing)
u, p = fixed_u(nw), fixed_p(nw); du = zeros(length(u))
nw(du, u, p, T0)
vb = nw.vertexbatches; eb = nw.layer.edgebatches
o, agg, ext = ND.get_buffers(nw, u, p, T0)
gbuf = ND.get_gbuf(nw.gbufprovider, o)
ex = SequentialExecution{true}()
for (name, bs, fg, inb, f) in (("vertex :f", vb, Val(:f), (agg, ext), ND.run_vertex_batch!), ("edge :fg", eb, Val(:fg), (gbuf, ext), ND.run_edge_batch!))
    args = Ref((ex, fg, inb, du, u, o, p, T0))
    m = ND.compiled_for(bs[1].model)
    println("== ", name, ": the kept value ", typeof(bs[1].model), "; compiled_for gives ", typeof(m))
    show(stdout, MIME"text/plain"(), fully_typed(ND._process_kept!, (typeof(ex), typeof(fg), typeof(ND.nofilt), typeof(bs), typeof(inb), typeof((du, u, o, p, T0))))); println()
    show(stdout, MIME"text/plain"(), fully_typed(f, (typeof(m), typeof(bs), Int, typeof(args)))); println()
end
