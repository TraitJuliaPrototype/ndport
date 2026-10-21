# G0 (b) and (c) of the graph plan: included by graph_probe.jl in setting P4 (top level: modules).
using TraitWorld

# (b) the declaration of the plan's §2.2, in a plain module (as in Graphs at G1)
module GDecl
using TraitWorld: @trait, @implement
using Graphs
using Graphs: AbstractGraph, SimpleEdge, all_neighbors
"The edges of `g` as `SimpleEdge`s, in the order of `edges(g)`."
edge_list(g::AbstractGraph{T}) where {T} = SimpleEdge{T}[SimpleEdge{T}(src(e), dst(e)) for e in edges(g)]
"The in- and out-neighbours of `v`, as `all_neighbors(g, v)` gives them, collected."
all_neighbor_list(g::AbstractGraph{T}, v::Integer) where {T} = collect(T, all_neighbors(g, v))
@trait GraphInterface{V <: Integer} begin
    V = eltype(Self)
    Graphs.nv(g::GraphInterface{V})::V
    Graphs.ne(g::GraphInterface)::Int
    Graphs.is_directed(g::GraphInterface)::Bool
    Graphs.has_edge(g::GraphInterface{V}, s::V, d::V)::Bool
    Graphs.degree(g::GraphInterface{V}, v::V)::Int
    edge_list(g::GraphInterface{V})::Vector{SimpleEdge{V}}
    all_neighbor_list(g::GraphInterface{V}, v::V)::Vector{V}
end
@implement GraphInterface G where {G <: AbstractGraph}
end

# the bounded probe, in a scratch trait module
@trait_module module GProbe
using TraitWorld
using Graphs
using ..GDecl: GraphInterface, edge_list, all_neighbor_list
function probe(g::GraphInterface{V}) where {V}
    (; V, nv = nv(g), ne = ne(g), dir = is_directed(g), he = has_edge(g, one(V), V(2)),
       deg = degree(g, one(V)), el = edge_list(g), nb = all_neighbor_list(g, one(V)))
end
# (c): code after each operation; a result inferred `Any` makes the arithmetic a run-time site
pc1(g::GraphInterface) = (n = nv(g); es = edge_list(g); (n + n, src(first(es)) + dst(first(es)), length(es)))
pc2(g::GraphInterface{V}) where {V} = (n = nv(g); es = edge_list(g); (n + one(V), src(first(es)) + one(V), length(es)))
pc3(g::GraphInterface{Int}) = (n = nv(g); es = edge_list(g); (n + 1, src(first(es)) + 1, length(es)))
# the operations whose declared results do not apply a bounded type constructor to `V`
pc4(g::GraphInterface{V}) where {V} = (n = nv(g); nb = all_neighbor_list(g, one(V)); (n + one(V), ne(g) + 1, first(nb) + one(V), degree(g, one(V)) + 1))
end

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

println("# G0 (b) the member table; TraitWorld ", pkgdir(TraitWorld), " Graphs ", pkgversion(Graphs), " at ", pkgdir(Graphs))
g32 = SimpleGraph{Int32}(g)
bcall(x) = GProbe.probe(x)     # a caller compiled for x's type: the graph is `Compiled` (the first-seen rule)
for (name, x) in (("SimpleGraph{Int64}", g), ("SimpleDiGraph{Int64}", d), ("SimpleGraph{Int32}", g32),
                  ("GenericGraph", generic_graph(g)), ("GenericDiGraph", generic_graph(d)),
                  ("ReverseView", Graphs.ReverseView(d)), ("UndirectedView", Graphs.UndirectedView(d)),
                  ("WrongNv", WrongNv(g32)))
    try
        t = @elapsed r = bcall(x)
        ok = r.nv == nv(x) && r.ne == ne(x) && r.dir == is_directed(x) && r.he == has_edge(x, 1, 2) &&
             r.deg == degree(x, 1) && [(Int(src(e)), Int(dst(e))) for e in r.el] == pairs_of(x) &&
             r.nb == collect(all_neighbors(x, 1))
        println("b ", name, " conforms: V=", r.V, " nv::", typeof(r.nv), " el::", typeof(r.el), " nb::", typeof(r.nb),
                " equal to the plain reads=", ok, @sprintf(" first call %.3f s", t))
    catch err
        println("b ", name, " REFUSED: ", nameof(typeof(err)))
        println("b ", name, "   message: ", replace(sprint(showerror, err), '\n' => " | "))
        println("b ", name, "   frames: ", frames(catch_backtrace()))
    end
end
let x = WrongNv(g32)                                   # refused again at a second call, and naming only `nv`
    msg = try bcall(x); "accepted" catch err; sprint(showerror, err) end
    ops = filter(o -> occursin("`$o`", msg), ["nv", "ne", "is_directed", "has_edge", "degree", "edge_list", "all_neighbor_list"])
    println("b WrongNv second call: ", occursin("WrongNv", msg) ? "names WrongNv" : "-", "; operations named: ", ops,
            "; Int64 ", occursin("Int64", msg), "; Int32 ", occursin("Int32", msg))
end

println("# G0 (c) traits §5.2: with_dynamic(g) at a bound")
for x in (g, g32)
    w = with_dynamic(x)
    for (name, f) in (("GraphInterface", GProbe.pc1), ("GraphInterface{V} where V", GProbe.pc2), ("GraphInterface{Int}", GProbe.pc3),
                      ("GraphInterface{V}, no edge_list", GProbe.pc4))
        (f === GProbe.pc3 && eltype(x) !== Int) && continue
        try
            rc = f(compiled_for(x))
        println("c ", eltype(x), " ", name, ": compiled ", rc, "::", typeof(rc))
        rd = f(w)
            rep = fully_typed(f, (typeof(w),))
            own = [h for h in rep.sites if h.caller.def isa Method && h.caller.def.name in (:pc1, :pc2, :pc3, :pc4)]
            println("c ", eltype(x), " ", name, ": dynamic ", rd, "::", typeof(rd), " compiled ", rc, " same=", rd === rc,
                    "; fully_typed: ", isfullytyped(rep), " sites=", length(rep.sites), " in the probe's own body=", length(own),
                    " declared dynamic=", rep.dynamic)
            for h in first(rep.sites, 6)
                println("c     site ", h.line, " ", h.callee, " in ", h.caller.def isa Method ? h.caller.def.name : h.caller)
            end
        catch err
            println("c ", eltype(x), " ", name, " FAILS: ", nameof(typeof(err)), ": ", short(err))
        end
    end
end
