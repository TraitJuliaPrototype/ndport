# The right-hand-side check of the traits plan (writeup/plans/2026-10-21-ndport-traits.md §2.5), E-152.
# For a set of networks and every execution style: the bits of `du` at a fixed u, p, t, and of
# get_buffers' o, aggbuf, extbuf; the sparsity pattern; whether tier S's two networks share a type;
# the allocations and time of one right-hand side (tier S).
#
#     julia -t 2 --project=<env> scripts/rhs_check.jl            (U: env_upstream; P: env_p4)
#
# Lines: `R <net> <style> du=… o=… agg=… ext=…`, `J <net> jac=…` (compared exactly with U's),
# `sametype=…`, `A <net> <style> allocs=… ns=…` (reported). Compare with
#     diff <(grep -E '^(R|J) ' U.log) <(grep -E '^(R|J) ' P.log)
using NetworkDynamics, Graphs, Printf
using NetworkDynamics: get_buffers

bits(x) = x === nothing ? "nothing" : string(hash(reinterpret(UInt64, collect(Float64, x))); base = 16)

include(joinpath(@__DIR__, "rhs_check_nets.jl"))

# ---- the checks ---------------------------------------------------------------------------------
const STYLES = [SequentialExecution{true}(), SequentialExecution{false}(),
                ThreadedExecution{true}(), ThreadedExecution{false}(),
                PolyesterExecution{true}(), PolyesterExecution{false}(),
                KAExecution{true}(), KAExecution{false}()]
stylename(ex) = string(nameof(typeof(ex)), "{", NetworkDynamics.usebuffer(ex), "}")


function rhs_bits(nw)
    u, p = fixed_u(nw), fixed_p(nw)
    du = zeros(length(u))
    nw(du, u, p, T0)
    # KAExecution's get_buffers fails upstream (get_backend(nothing)): the buffers' fields say so
    bufs = try
        o, agg, ext = get_buffers(nw, u, p, T0)
        (; o = bits(o), agg = bits(agg), ext = bits(ext))
    catch err
        e = "error:" * string(nameof(typeof(err)))
        (; o = e, agg = e, ext = e)
    end
    (; du = bits(du), bufs...)
end

function cost(nw)
    u, p = fixed_u(nw), fixed_p(nw)
    du = zeros(length(u))
    nw(du, u, p, T0); nw(du, u, p, T0)
    allocs = @allocated nw(du, u, p, T0)
    ns = minimum(1:3) do _
        t0 = time_ns()
        for _ in 1:10_000
            nw(du, u, p, T0)
        end
        (time_ns() - t0) / 10_000
    end
    (; allocs, ns)
end

const NETS = [("S-swing", kw -> tierS(:swing; kw...)), ("S-swing2", kw -> tierS(:swing2; kw...)), ("ff", kw -> ffnet(; kw...))]

println("# rhs_check threads=", Threads.nthreads(), " julia=", VERSION, " nd=", pkgdir(NetworkDynamics))
for (name, make) in NETS
    for ex in STYLES
        r = try
            rhs_bits(make((; execution = ex)))
        catch err
            println("E ", name, " ", stylename(ex), " ", sprint(showerror, err)[1:min(end, 300)])
            continue
        end
        println("R ", name, " ", stylename(ex), " du=", r.du, " o=", r.o, " agg=", r.agg, " ext=", r.ext)
    end
    jac = try
        sprint(show, get_jac_prototype(make((;))))
    catch err
        "error:" * sprint(showerror, err)[1:min(end, 200)]
    end
    println("J ", name, " jac=", string(hash(jac); base = 16))
end

nwa, nwb = tierS(:swing), tierS(:swing2)
println("sametype=", typeof(nwa) === typeof(nwb))
for (name, nw) in (("S-swing", nwa), ("S-swing2", nwb))
    for ex in (SequentialExecution{true}(), ThreadedExecution{true}())
        c = cost(tierS(name == "S-swing" ? :swing : :swing2; execution = ex))
        @printf("A %s %s allocs=%d ns=%.0f\n", name, stylename(ex), c.allocs, c.ns)
    end
end

# ---- S1 on: the operations on a kept model give apply_compf's and apply_compg's bits ------------
# (until P4 step 3's traits per kind; from then on the S3 lines below)
if isdefined(NetworkDynamics, :ComponentDynamics) && !isdefined(NetworkDynamics, :VertexDynamics)
    ND = NetworkDynamics
    function s1check(name, nw)
        comps = vcat(collect(nw.im.vertexm), collect(nw.im.edgem))
        for c in unique(comps)
            isv = c isa VertexModel
            fd = ND.FunctionDynamics(ND.compf(c), ND.compg(c), ND.fftype(c), ND.pdim(c), ND.extdim(c))
            k = ND.Kept{ND.ComponentDynamics}(fd)
            buf(n, s) = [sin(s * i) + 0.1i for i in 1:n]
            u = buf(ND.dim(c), 0.3)
            p = ND.pdim(c) == 0 ? nothing : buf(ND.pdim(c), 0.7)
            ins = isv ? (buf(nw.im.edepth, 0.5),) : (buf(nw.im.vdepth, 0.5), buf(nw.im.vdepth, 0.9))
            ND.extdim(c) > 0 && (ins = (ins..., buf(ND.extdim(c), 1.1)))
            nout = isv ? (ND.outdim(c),) : (ND.outdim(c).src, ND.outdim(c).dst)
            fok = if ND.compf(c) === nothing
                ND.hasf(k) === false
            else
                du1, du2 = zeros(ND.dim(c)), zeros(ND.dim(c))
                ND.apply_compf(ND.compf(c), du1, u, ins, p, T0)
                ND.compf!(k, du2, u, ins, p, T0)
                ND.hasf(k) && bits(du1) == bits(du2)
            end
            o1, o2 = map(zeros, nout), map(zeros, nout)
            ND.apply_compg(ND.fftype(c), ND.compg(c), o1, u, ins, p, T0)
            ND.compg!(k, o2, u, ins, p, T0)
            gok = all(bits(a) == bits(b) for (a, b) in zip(o1, o2))
            sok = ND.fftype(k) === ND.fftype(c) && ND.pdim(k) == ND.pdim(c) && ND.extdim(k) == ND.extdim(c)
            println("S1 ", name, " ", ND.compf(c) === nothing ? "-" : nameof(ND.compf(c)), "/", typeof(ND.fftype(c)).name.name,
                    " f=", fok, " g=", gok, " static=", sok)
        end
    end
    for (name, make) in NETS
        s1check(name, make((;)))
    end
end

# ---- P4 step 3 (E-166) on, lines `K`: the kind's operations on a kept model give apply_compf's and apply_compg's bits ----
if isdefined(NetworkDynamics, :VertexDynamics)
    ND = NetworkDynamics
    function s3check(name, nw)
        comps = vcat(collect(nw.im.vertexm), collect(nw.im.edgem))
        for c in unique(comps)
            isv = c isa VertexModel
            fd = ND.FunctionDynamics(ND.compf(c), ND.compg(c), ND.fftype(c), ND.pdim(c), ND.extdim(c))
            k = isv ? ND.Kept{ND.VertexDynamics}(fd) : ND.Kept{ND.EdgeDynamics}(fd)
            # the supertrait's operations from plain code take a kept value of the supertrait: a Kept{VertexDynamics}
            # is not accepted by `hasf` (MethodError; E-166 notes, a candidate row)
            kc = ND.Kept{ND.ComponentDynamics}(fd)
            buf(n, s) = [sin(s * i) + 0.1i for i in 1:n]
            u = buf(ND.dim(c), 0.3)
            p = ND.pdim(c) == 0 ? nothing : buf(ND.pdim(c), 0.7)
            ins = isv ? (buf(nw.im.edepth, 0.5),) : (buf(nw.im.vdepth, 0.5), buf(nw.im.vdepth, 0.9))
            ND.extdim(c) > 0 && (ins = (ins..., buf(ND.extdim(c), 1.1)))
            nout = isv ? (ND.outdim(c),) : (ND.outdim(c).src, ND.outdim(c).dst)
            fok = if ND.compf(c) === nothing
                ND.hasf(kc) === false
            else
                du1, du2 = zeros(ND.dim(c)), zeros(ND.dim(c))
                ND.apply_compf(ND.compf(c), du1, u, ins, p, T0)
                isv ? ND.vertexf!(k, du2, u, ins, p, T0) : ND.edgef!(k, du2, u, ins, p, T0)
                ND.hasf(kc) && bits(du1) == bits(du2)
            end
            o1, o2 = map(zeros, nout), map(zeros, nout)
            ND.apply_compg(ND.fftype(c), ND.compg(c), o1, u, ins, p, T0)
            isv ? ND.vertexg!(k, o2[1], u, ins, p, T0) : ND.edgeg!(k, o2[1], o2[2], u, ins, p, T0)
            gok = all(bits(a) == bits(b) for (a, b) in zip(o1, o2))
            sok = ND.fftype(kc) === ND.fftype(c) && ND.pdim(kc) == ND.pdim(c) && ND.extdim(kc) == ND.extdim(c)
            println("K ", name, " ", isv ? "vertex " : "edge ", ND.compf(c) === nothing ? "-" : nameof(ND.compf(c)), "/",
                    typeof(ND.fftype(c)).name.name, " f=", fok, " g=", gok, " static=", sok)
        end
    end
    for (name, make) in NETS
        s3check(name, make((;)))
    end
end

# ---- S2 on: Int strides give the same ranges, fully typed ----------------------------------------
if isdefined(NetworkDynamics, :_dynamic)
    ND = NetworkDynamics
    using TraitWorld: fully_typed, isfullytyped
    function s2check(name, nw)
        ok = true
        for b in (nw.vertexbatches..., nw.layer.edgebatches...)
            for s in (b.statestride, b.pstride, b.inbufstride, b.outbufstride, b.extbufstride)
                d = ND._dynamic(s)
                for i in 1:length(b)
                    if s.strides isa NamedTuple
                        ok &= ND._range(d, i, :src) == ND._range(s, i, :src) && ND._range(d, i, :dst) == ND._range(s, i, :dst)
                    else
                        ok &= ND._range(d, i) == ND._range(s, i)
                    end
                end
            end
        end
        println("S2 ", name, " ranges=", ok)
    end
    for (name, make) in NETS
        s2check(name, make((;)))
    end
    for T in ((ND.BatchStride{Int}, Int), (ND.BatchStride{@NamedTuple{src::Int, dst::Int}}, Int, Symbol))
        r = fully_typed(ND._range, T)
        println("S2 fully_typed _range", T, " ", isfullytyped(r), isfullytyped(r) ? "" : string(" ", r))
    end
end

# ---- S3 on: a batch kept and erased; `@set` keeps its kind ---------------------------------------
if hasfield(NetworkDynamics.ComponentBatch, :model)
    ND = NetworkDynamics
    rebuild(b; kw...) = ND.ComponentBatch(ND.dispatchT(b), b.indices, b.compf, b.compg, b.ff, b.statestride, b.pstride,
                                          b.inbufstride, b.outbufstride, b.extbufstride; kw...)
    erasedT = Dict{String,Any}()
    # from P4 step 3 the batch keeps its kind's trait; plain code reads the supertrait's facts through a kept value of
    # the supertrait (a Kept{VertexDynamics} is not accepted by `fftype`: E-166 notes, a candidate row)
    cdview(m) = isdefined(ND, :VertexDynamics) ? ND.Kept{ND.ComponentDynamics}(getfield(m, :t)) : ND.compiled_for(m)
    for (name, make) in NETS
        nw = make((; execution = PolyesterExecution{true}()))     # typed batches (Polyester keeps them)
        for b in (nw.vertexbatches..., nw.layer.edgebatches...)
            b.model === nothing || continue
            e = rebuild(b; kept = true, erased = true)
            k = rebuild(b; kept = true)
            e2 = NetworkDynamics.Accessors.@set e.compf = e.compf
            k2 = NetworkDynamics.Accessors.@set k.compg = k.compg
            ok = typeof(e2) === typeof(e) && typeof(k2) === typeof(k) && e2.model !== nothing &&
                 ND.state_range(e, 1) == ND.state_range(b, 1) && ND.parameter_range(e, length(e)) == ND.parameter_range(b, length(b)) &&
                 ND.fftype(cdview(e.model)) === b.ff && ND.pdim(cdview(e.model)) == ND.pdim(b)
            name in ("S-swing", "S-swing2") && ND.dispatchT(b) === VertexModel && (erasedT[name] = typeof(e))
            println("S3 ", name, " ", ND.dispatchT(b), " ", b.compf === nothing ? "-" : nameof(b.compf), " ok=", ok)
        end
    end
    println("S3 erased vertex batches of swing!, swing2! of one type: ", erasedT["S-swing"] === erasedT["S-swing2"], " ", erasedT["S-swing"])
end

# ---- S4 on: the bounded batch functions on an erased batch give apply_comp!'s bits ----------------
if isdefined(NetworkDynamics, :run_vertex_batch!)
    ND = NetworkDynamics
    function s4check(name, nw, ex)
        u, p = fixed_u(nw), fixed_p(nw)
        o0, agg, ext = get_buffers(nw, u, p, T0)
        gbuf = ND.get_gbuf(nw.gbufprovider, o0)
        ok = true
        for b in (nw.vertexbatches..., nw.layer.edgebatches...), fg in (Val(:f), Val(:g), Val(:fg))
            T = ND.dispatchT(b)
            inbufs = T === VertexModel ? (agg, ext) : (gbuf, ext)
            e = b.model === nothing ? rebuild(b; kept = true, erased = true) : b
            du1, o1 = zeros(length(u)), copy(o0)
            for i in 1:length(b)
                ND.apply_comp!(T, fg, b, i, du1, u, o1, inbufs, p, T0)
            end
            du2, o2 = zeros(length(u)), copy(o0)
            args = Ref((ex, fg, inbufs, du2, u, o2, p, T0))
            m = ND.compiled_for(e.model)
            T === VertexModel ? ND.run_vertex_batch!(m, [e], 1, args) : ND.run_edge_batch!(m, [e], 1, args)
            ok &= bits(du1) == bits(du2) && bits(o1) == bits(o2)
        end
        println("S4 ", name, " ", stylename(ex), " batchfns=", ok)
    end
    for (name, make) in NETS, ex in (SequentialExecution{true}(), ThreadedExecution{false}())
        s4check(name, make((; execution = ex)), ex)
    end
end
