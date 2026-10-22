# E-166, S3-0 (b) and check X: tier S's right-hand side split. The right-hand side, then per pass the crossing into
# an empty batch and into the full batch, the work alone, `process_batches!`, the `Ref`; the same network with typed
# batches (Polyester's serial path, one thread). From the planning probes `p4s3-planning/split_probe*.jl`.
# Minimum of three timings of 2·10⁵ calls. Run in setting M (NDW_SCRIPT=scripts/p4s3_rhs_split.jl).
using NetworkDynamics, Graphs, Printf
const ND = NetworkDynamics
include(joinpath(@__DIR__, "rhs_check_nets.jl"))
nw = tierS(:swing)
u, p = fixed_u(nw), fixed_p(nw); du = zeros(length(u))
rhs(nw, du, u, p) = nw(du, u, p, T0)
rhs(nw, du, u, p); rhs(nw, du, u, p)
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
tmin(f) = minimum(tm(f) for _ in 1:3)
# every timed call behind a function barrier, its arguments captured as a concrete tuple (no global reads)
bench(f, args...) = (g = () -> f(args...); (tmin(g), @allocations(g())))
showb(label, (t, a)) = @printf("X %s ns=%.0f allocs=%d\n", label, t, a)
bytes(f, args...) = (g = () -> f(args...); g(); g(); @allocated g())
println("ND ", pathof(ND))
vb = nw.vertexbatches; eb = nw.layer.edgebatches
println("vertex batches ", length(vb), " edge batches ", length(eb), " sizes ", length.(vb), " ", length.(eb))
showb("rhs", bench(rhs, nw, du, u, p))
@printf("X rhs bytes=%d\n", bytes(rhs, nw, du, u, p))
o, agg, ext = ND.get_buffers(nw, u, p, T0)
gbuf = ND.get_gbuf(nw.gbufprovider, o); ND.gather!(nw.gbufprovider, gbuf, o)
ex = SequentialExecution{true}()
emptied(b) = [ND.ComponentBatch(ND.dispatchT(b), Int[], b.compf, b.compg, b.ff, b.statestride, b.pstride, b.inbufstride,
                               b.outbufstride, b.extbufstride; kept = true, erased = true)]
isedge(bs) = ND.dispatchT(bs[1]) === EdgeModel
crossf(bs, args) = isedge(bs) ? ND.run_edge_batch!(ND.compiled_for(bs[1].model), bs, 1, args) :
                                ND.run_vertex_batch!(ND.compiled_for(bs[1].model), bs, 1, args)
work(fd, fg, b, isedge, du, u, o, inb, p) = (for i in 1:length(b); isedge ? ND._edge!(fd, fg, b, i, du, u, o, inb, p, T0) : ND._vertex!(fd, fg, b, i, du, u, o, inb, p, T0); end; nothing)
for (name, bs, fg, inb) in (("vertex :g", vb, Val(:g), (nothing, nothing)), ("edge :fg", eb, Val(:fg), (gbuf, ext)), ("vertex :f", vb, Val(:f), (agg, ext)))
    args = Ref((ex, fg, inb, du, u, o, p, T0))
    be = emptied(bs[1])
    fd = getfield(bs[1].model, :t)   # the held FunctionDynamics
    try
        showb("$name full batch ($(length(bs[1])))", bench(crossf, bs, args))
        showb("$name empty batch", bench(crossf, be, args))
        showb("$name work alone (the held FunctionDynamics, typed)", bench(work, fd, fg, bs[1], isedge(bs), du, u, o, inb, p))
    catch err
        println("X ", name, " error ", sprint(showerror, err)[1:min(end, 300)])
    end
end
for (name, bs, fg, filt, inb) in (("vertex :g", vb, Val(:g), !ND.hasff, (nothing, nothing)), ("edge :fg", eb, Val(:fg), ND.hasff, (gbuf, ext)), ("vertex :f", vb, Val(:f), !ND.hasff, (agg, ext)))
    showb("$name process_batches!", bench(ND.process_batches!, ex, fg, filt, bs, inb, (du, u, o, p, T0)))
    @printf("X %s process_batches! bytes=%d\n", name, bytes(ND.process_batches!, ex, fg, filt, bs, inb, (du, u, o, p, T0)))
end
cfk(v) = ND.compiled_for(v[1].model)
showb("compiled_for(kept)", bench(cfk, vb))
mkref(ex, fg, inb, du, u, o, p) = Ref((ex, fg, inb, du, u, o, p, T0))
showb("Ref of the pass's arguments", bench(mkref, ex, Val(:f), (agg, ext), du, u, o, p))
nwt = tierS(:swing; execution = PolyesterExecution{true}())
rhs(nwt, du, u, p)
showb("typed batches rhs", bench(rhs, nwt, du, u, p))
