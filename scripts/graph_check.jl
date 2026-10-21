# Check (C) of the graph plan (writeup/plans/2026-10-21-ndport-graph.md §3), E-154, in env_p4 after G1:
#     julia --project=env_p4 scripts/graph_check.jl            (from ndport/)
# The references: SimpleGraph{Int32}(g) and GenericGraph(g) against g; GenericDiGraph(d) against d;
# UndirectedView(d) against SimpleGraph(d); ReverseView(d) against itself in check-g1.log (before G2), since
# reverse(d) has the same edges in another order.
# Lines:
#   `M <type> …`  the member table of §2.5 through a bounded probe (Graphs.GraphInterface);
#   `N <type> …`  `Network` on the type with tier S's models: nv, ne, edgevec and the bits of `du` (as
#                 rhs_check.jl computes them) against the network on the type's reference (§2.5);
#                 `ff` the feed-forward network (rhs_check.jl's ffnet) on a GenericDiGraph;
#   `W …`         `Network` on WrongNv: the error, its type and the frame it is raised in.
using TraitWorld, Graphs, NetworkDynamics, Printf
using Graphs.Test: generic_graph
include(joinpath(@__DIR__, "rhs_check_nets.jl"))      # swing!, line!, ffnet, fixed_u, fixed_p, T0

bits(x) = string(hash(reinterpret(UInt64, collect(Float64, x))); base = 16)
pairs_of(x) = [(Int(src(e)), Int(dst(e))) for e in edges(x)]
function frames(bt; n = 4)
    fs = [f for f in Base.StackTraces.stacktrace(bt) if occursin(r"NetworkDynamics|Graphs|TraitWorld", string(f.file))]
    join((string(f.func, "@", basename(string(f.file)), ":", f.line) for f in first(fs, n)), " < ")
end
println("# graph_check Graphs ", pkgdir(Graphs), " ND ", pkgdir(NetworkDynamics), " GraphInterface ",
        isdefined(Graphs, :GraphInterface))

g = watts_strogatz(20, 4, 0.2; seed = 42)
d = SimpleDiGraph(collect(edges(g)))           # the same 40 edges, each from the smaller vertex
g32 = SimpleGraph{Int32}(g)

# a user's type whose methods exist but `nv` returns the wrong type (plain code)
struct WrongNv <: Graphs.AbstractGraph{Int32}
    g::SimpleGraph{Int32}
end
Graphs.is_directed(::Type{WrongNv}) = false
Graphs.vertices(w::WrongNv) = vertices(w.g)
Graphs.edges(w::WrongNv) = edges(w.g)
Graphs.outneighbors(w::WrongNv, v::Integer) = outneighbors(w.g, v)
Graphs.inneighbors(w::WrongNv, v::Integer) = inneighbors(w.g, v)
Graphs.has_edge(w::WrongNv, s::Integer, t::Integer) = has_edge(w.g, s, t)
Graphs.ne(w::WrongNv) = ne(w.g)
Graphs.nv(w::WrongNv) = Int64(nv(w.g))

# ---- M: the member table through a bounded probe -----------------------------------------------
@trait_module module GProbe
using TraitWorld
using Graphs
using Graphs: GraphInterface, edge_list, all_neighbor_list
function probe(g::GraphInterface{V}) where {V}
    (; V, nv = nv(g), ne = ne(g), dir = is_directed(g), he = has_edge(g, one(V), V(2)),
       deg = degree(g, one(V)), el = edge_list(g), nb = all_neighbor_list(g, one(V)))
end
end
bcall(x) = GProbe.probe(x)     # a caller compiled for x's type: the graph is `Compiled` (the first-seen rule)

const TYPES = [("SimpleGraph{Int64}", g, g), ("SimpleDiGraph{Int64}", d, d), ("SimpleGraph{Int32}", g32, g),
               ("GenericGraph", generic_graph(g), g), ("GenericDiGraph", generic_graph(d), d),
               ("ReverseView", Graphs.ReverseView(d), :before), ("UndirectedView", Graphs.UndirectedView(d), SimpleGraph(d))]
for (name, x, _) in [TYPES; [("WrongNv", WrongNv(g32), nothing)]]
    try
        t = @elapsed r = bcall(x)
        ok = r.nv == nv(x) && r.ne == ne(x) && r.dir == is_directed(x) && r.he == has_edge(x, 1, 2) &&
             r.deg == degree(x, 1) && [(Int(src(e)), Int(dst(e))) for e in r.el] == pairs_of(x) &&
             r.nb == collect(all_neighbors(x, 1))
        println("M ", name, " conforms: V=", r.V, " equal to the plain reads=", ok, @sprintf(" first call %.3f s", t))
    catch err
        msg = sprint(showerror, err)
        ops = filter(o -> occursin("`$o`", msg), ["nv", "ne", "is_directed", "has_edge", "degree", "edge_list", "all_neighbor_list"])
        println("M ", name, " REFUSED: ", nameof(typeof(err)), "; operations named: ", ops, "; message: ", replace(msg, '\n' => " | "))
    end
end

# ---- N: Network on each type against its reference ---------------------------------------------
vertex = VertexModel(f = swing!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1])
edge = EdgeModel(g = AntiSymmetric(line!), outsym = :P, psym = [:K => 6.0, :limit => 1.0])
netS(x) = Network(x, vertex, edge; dealias = true)
function du_bits(nw)
    u, p = fixed_u(nw), fixed_p(nw)
    du = zeros(length(u))
    nw(du, u, p, T0)
    bits(du)
end
summary_of(nw) = (; nv = nv(nw), ne = ne(get_graph(nw)), ev = [(e.src, e.dst) for e in nw.im.edgevec], du = du_bits(nw))
for (name, x, ref) in TYPES
    name == "UndirectedView" && println("N UndirectedView: edge order equal to SimpleGraph(d)'s: ", pairs_of(x) == pairs_of(ref))
    if ref === :before          # reverse(d) has the same edges in another order: compared with check-g1's line
        println("N ReverseView: edge set equal to reverse(d)'s: ", sort(pairs_of(x)) == sort(pairs_of(reverse(d))),
                ", order equal: ", pairs_of(x) == pairs_of(reverse(d)))
        try
            a = summary_of(netS(x))
            println("N ReverseView builds: nv=", a.nv, " ne=", a.ne, " du=", a.du, " edgevec=", string(hash(a.ev); base = 16),
                    " | ref: the same graph before G2 (check-g1.log)")
        catch err
            println("N ", name, " FAILS: ", nameof(typeof(err)), ": ", replace(sprint(showerror, err)[1:min(end, 300)], '\n' => " | "))
        end
        continue
    end
    try
        a = summary_of(netS(x))
        b = summary_of(netS(ref))
        println("N ", name, " builds: nv=", a.nv, " ne=", a.ne, " du=", a.du, " | ref: nv ", a.nv == b.nv, " ne ", a.ne == b.ne,
                " edgevec ", a.ev == b.ev, " du ", a.du == b.du)
    catch err
        println("N ", name, " FAILS: ", nameof(typeof(err)), ": ", replace(sprint(showerror, err)[1:min(end, 300)], '\n' => " | "))
        println("N ", name, "   frames: ", frames(catch_backtrace()))
    end
end
let gg = SimpleDiGraph(6)                                   # the feed-forward check (construction.jl)
    for (s, t) in ((1, 2), (2, 3), (3, 4), (4, 1), (5, 1), (6, 2)); add_edge!(gg, s, t); end
    nw0 = ffnet()
    try
        a = summary_of(Network(generic_graph(gg), copy.(nw0.im.vertexm), copy.(nw0.im.edgem)))
        b = summary_of(Network(gg, copy.(nw0.im.vertexm), copy.(nw0.im.edgem)))
        println("N ff GenericDiGraph builds: du=", a.du, " | ref: edgevec ", a.ev == b.ev, " du ", a.du == b.du, " (ffnet() du ", du_bits(nw0) == b.du, ")")
    catch err
        println("N ff GenericDiGraph FAILS: ", nameof(typeof(err)), ": ", replace(sprint(showerror, err)[1:min(end, 300)], '\n' => " | "))
        println("N ff GenericDiGraph   frames: ", frames(catch_backtrace()))
    end
    # the check's own refusals, on both graph types: a feed-forward vertex with two neighbours
    for (name, x) in (("SimpleDiGraph", gg), ("GenericDiGraph", generic_graph(gg)))
        vm = copy.(nw0.im.vertexm); vm[1], vm[5] = vm[5], vm[1]    # the injector at the hub's place
        msg = try Network(x, vm, copy.(nw0.im.edgem)); "accepted" catch err; string(nameof(typeof(err)), ": ", first(sprint(showerror, err), 60)) end
        println("N ff refusal ", name, ": ", msg)
    end
end

# ---- W: Network on WrongNv ----------------------------------------------------------------------
try
    netS(WrongNv(g32))
    println("W WrongNv: Network accepted it")
catch err
    println("W WrongNv: ", nameof(typeof(err)), ": ", replace(sprint(showerror, err), '\n' => " | "))
    println("W WrongNv   frames: ", frames(catch_backtrace(); n = 12))
end
