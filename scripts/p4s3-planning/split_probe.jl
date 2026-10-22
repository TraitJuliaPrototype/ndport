# Diagnostic for the step-3 plan: tier S's right-hand side split into the crossings and the batches' work.
# Not a measurement round. Run in env_merged with depot-merged.
using NetworkDynamics, Graphs, Printf
const ND = NetworkDynamics
include("/home/hellmann/Repos/julia-trait-bound/ndport/scripts/rhs_check_nets.jl")
nw = tierS(:swing)
u, p = fixed_u(nw), fixed_p(nw); du = zeros(length(u))
rhs(nw, du, u, p) = nw(du, u, p, T0)
rhs(nw, du, u, p); rhs(nw, du, u, p)
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
vb = nw.vertexbatches; eb = nw.layer.edgebatches
println("vertex batches ", length(vb), " edge batches ", length(eb), " sizes ", length.(vb), " ", length.(eb))
o, agg, ext = ND.get_buffers(nw, u, p, T0)
ex = SequentialExecution{true}()
@printf("rhs ns=%.0f allocs=%d\n", tm(() -> rhs(nw, du, u, p)), @allocations(rhs(nw, du, u, p)))
gbuf = ND.get_gbuf(nw.gbufprovider, o); ND.gather!(nw.gbufprovider, gbuf, o)
for (name, bs, fg, inb) in (("vertex :f", vb, Val(:f), (agg, ext)), ("vertex :g", vb, Val(:g), (nothing, nothing)), ("edge :fg", eb, Val(:fg), (gbuf, ext)))
    args = Ref((ex, fg, inb, du, u, o, p, T0))
    fd = getfield(bs[1].model, :t)   # the held FunctionDynamics (the kept value's object)
    println(name, ": held ", typeof(fd).name.name, " compiled=", getfield(bs[1].model, :compiled))
    isedge = ND.dispatchT(bs[1]) === EdgeModel
    cross() = isedge ? ND.run_edge_batch!(ND.compiled_for(bs[1].model), bs, 1, args) : ND.run_vertex_batch!(ND.compiled_for(bs[1].model), bs, 1, args)
    work() = (b = bs[1]; for i in 1:length(b); isedge ? ND._edge!(fd, fg, b, i, du, u, o, inb, p, T0) : ND._vertex!(fd, fg, b, i, du, u, o, inb, p, T0); end; nothing)
    try
        @printf("%-10s crossing+work ns=%.0f allocs=%d | work alone ns=%.0f allocs=%d\n", name,
                tm(cross), @allocations(cross()), tm(work), @allocations(work()))
    catch err
        println(name, " error ", typeof(err))
    end
end
# the process_batches! overhead per pass (the Ref, the filters), against the crossing alone
for (name, bs, fg, filt, inb) in (("vertex :f", vb, Val(:f), !ND.hasff, (agg, ext)), ("vertex :g", vb, Val(:g), !ND.hasff, (nothing, nothing)), ("edge :fg", eb, Val(:fg), ND.hasff, (gbuf, ext)))
    pk() = ND.process_batches!(ex, fg, filt, bs, inb, (du, u, o, p, T0))
    @printf("%-10s process_batches! ns=%.0f allocs=%d\n", name, tm(pk), @allocations(pk()))
end
# the same network with typed batches (Polyester keeps upstream's batches; one thread: its serial path)
nwt = tierS(:swing; execution = PolyesterExecution{true}())
rhs(nwt, du, u, p)
@printf("typed batches rhs ns=%.0f allocs=%d\n", tm(() -> rhs(nwt, du, u, p)), @allocations(rhs(nwt, du, u, p)))
