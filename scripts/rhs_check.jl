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

# ---- tier S: the workload's components (scripts/workload_steps.jl, step a) -------------------------
function swing!(dv, v, esum, p, t)
    P, I, γ = p
    dv[1] = v[2]
    dv[2] = (P - γ * v[2] + esum[1]) / I
    nothing
end
function swing2!(dv, v, esum, p, t)
    P, I, γ, κ = p
    dv[1] = v[2]
    dv[2] = (P - γ * v[2] - κ * v[2]^3 + esum[1]) / I
    nothing
end
line!(e, v_s, v_d, (K,), t) = (e[1] = K * sin(v_s[1] - v_d[1]); nothing)

function tierS(model::Symbol; kw...)
    vertex = model === :swing ?
        VertexModel(f = swing!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1]) :
        VertexModel(f = swing2!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1, :κ => 0.5])
    edge = EdgeModel(g = AntiSymmetric(line!), outsym = :P, psym = [:K => 6.0, :limit => 1.0])
    Network(watts_strogatz(20, 4, 0.2; seed = 42), vertex, edge; dealias = true, kw...)
end

# ---- the feed-forward kinds, loopback edges, external inputs (the review's finding 7) -------------
# hubs 1–4 on a ring, each vertex model distinct; injectors 5 (FeedForward) and 6 (PureFeedForward)
# hang on hubs 1 and 2 by loopback edges.
fhub!(du, u, i, p, t) = (du[1] = p[1] * i[1] - p[2] * u[1] + 0.1 * sin(t); nothing)
fhub0!(du, u, i, p, t) = (du[1] = i[1] - 0.5 * u[1]; nothing)                      # pdim 0: p === nothing
fhubext!(du, u, i, ext, p, t) = (du[1] = i[1] + p[1] * ext[1] - u[1]; nothing)     # an external input
ghub_noff!(o, u, p, t) = (o[1] = p[3] * u[1]; nothing)                             # NoFeedForward
finj!(du, u, i, p, t) = (du[1] = p[1] * (i[1] - u[1]); nothing)
ginj_ff!(o, u, i, p, t) = (o[1] = p[2] * (u[1] - i[1]); nothing)                   # FeedForward
ginj_pff!(o, i, p, t) = (o[1] = p[1] * i[1]; nothing)                              # PureFeedForward, dim 0

fedge!(de, e, vs, vd, p, t) = (de[1] = p[1] * (vs[1] - vd[1]) - e[1]; nothing)
gedge_ff!(os, od, e, vs, vd, p, t) = (od[1] = e[1] + p[2] * (vs[1] - vd[1]); os[1] = -od[1]; nothing)   # FeedForward
gedge_noff!(os, od, e, p, t) = (od[1] = p[2] * e[1]; os[1] = -od[1]; nothing)                          # NoFeedForward
fedgeext!(de, e, vs, vd, ext, p, t) = (de[1] = ext[1] - e[1] + p[1] * vs[1]; nothing)

function ffnet(; kw...)
    g = SimpleDiGraph(6)
    for (s, d) in ((1, 2), (2, 3), (3, 4), (4, 1), (5, 1), (6, 2))
        add_edge!(g, s, d)
    end
    v1 = VertexModel(f = fhub!, g = ghub_noff!, sym = [:x], outsym = [:y], psym = [:a => 1.1, :b => 0.4, :c => 1.3], insym = [:i], name = :hub_noff)
    v2 = VertexModel(f = fhub!, g = 1, sym = [:x], psym = [:a => 0.9, :b => 0.6], insym = [:i], name = :hub_sm)
    v3 = VertexModel(f = fhub0!, g = 1, sym = [:x], insym = [:i], name = :hub_p0)
    v4 = VertexModel(f = fhubext!, g = 1, sym = [:x], psym = [:a => 0.7], insym = [:i], extin = [VIndex(2, :x)], name = :hub_ext)
    v5 = VertexModel(f = finj!, g = ginj_ff!, sym = [:x], outsym = [:i], psym = [:a => 0.8, :b => 1.2], insym = [:u], name = :inj_ff)
    v6 = VertexModel(g = ginj_pff!, outsym = [:i], psym = [:a => 0.5], insym = [:u], name = :inj_pff)
    e12 = EdgeModel(g = AntiSymmetric(line!), outsym = [:P], psym = [:K => 6.0], name = :e_pff)
    e23 = EdgeModel(f = fedge!, g = gedge_ff!, sym = [:e], outsym = (; src = [:P], dst = [:P]), psym = [:k => 0.3, :m => 0.8], name = :e_ff)
    e34 = EdgeModel(f = fedge!, g = gedge_noff!, sym = [:e], outsym = (; src = [:P], dst = [:P]), psym = [:k => 0.2, :m => 1.5], name = :e_noff)
    e41 = EdgeModel(f = fedgeext!, g = AntiSymmetric(1), sym = [:e], psym = [:k => 0.4], extin = [VIndex(3, :x)], name = :e_sm_ext)
    l51 = LoopbackConnection(; potential = [:u], flow = [:i])
    l62 = LoopbackConnection(; potential = [:u], flow = [:i])
    Network(g, [v1, v2, v3, v4, v5, v6], [e12, e23, e34, e41, l51, l62]; kw...)
end

# ---- the checks ---------------------------------------------------------------------------------
const STYLES = [SequentialExecution{true}(), SequentialExecution{false}(),
                ThreadedExecution{true}(), ThreadedExecution{false}(),
                PolyesterExecution{true}(), PolyesterExecution{false}(),
                KAExecution{true}(), KAExecution{false}()]
stylename(ex) = string(nameof(typeof(ex)), "{", NetworkDynamics.usebuffer(ex), "}")

fixed_u(nw) = [sin(0.37i) + 0.05i for i in 1:dim(nw)]
fixed_p(nw) = [1.0 + 0.5 * cos(0.61i) for i in 1:pdim(nw)]
const T0 = 0.3

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
