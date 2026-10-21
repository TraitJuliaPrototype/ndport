# G3's failure narrowed: which call of a function bounded by Graphs.GraphInterface, from trait code, raises
# `FieldError: type UnionAll has no field parameters`? (the graph plan, G3; E-154). In env_p4 after G1.
using TraitWorld, Graphs, NetworkDynamics
@trait_module module R
using TraitWorld, Graphs
using Graphs: GraphInterface, all_neighbor_list, AbstractGraph
using NetworkDynamics: VertexModel, EdgeModel
f1(g::GraphInterface{V}) where {V} = V
f2(g::GraphInterface{V}, a, b) where {V} = V
f3(g::GraphInterface{V}, a, b) where {V} = (nbs = map(i -> all_neighbor_list(g, V(i)), a); length(nbs))
f4(g::GraphInterface{V}, a::Vector{<:VertexModel}, b) where {V} = V
c1(g::AbstractGraph) = f1(g)
c2(g::AbstractGraph, a, b) = f2(g, a, b)
c3(g::AbstractGraph, a, b) = f3(g, a, b)
c2u(g, a, b) = f2(g, a, b)
c4(g::AbstractGraph, a, b) = f4(g, a, b)
c4u(g, a, b) = f4(g, a, b)
c4v(g, a::Vector{VertexModel}, b) = f4(g, a, b)
c4w(g, a::Union{VertexModel,Vector{<:VertexModel}}, b) = (aa = a isa VertexModel ? [a] : a; f4(g, aa, b))
using Graphs: SimpleEdge, edge_list
f5(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g); all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end)
f5b(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g); all(zip(a, a)) do (s, d); SimpleEdge{Int}(s, d) ∈ es end)
f5c(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g); all(t -> SimpleEdge{V}(t[1], t[2]) ∈ es, zip(a, a)))
f5d(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g); any(e -> e == SimpleEdge{V}(1, 2), es))
f5e(g::GraphInterface{V}, a, b) where {V} = (W = V; es = edge_list(g); any(e -> e == SimpleEdge{W}(1, 2), es))
f6(g::GraphInterface{V}, a, b) where {V} = (length(a) > 5 && throw(ArgumentError("x $(b[1])")); nothing)
f7(g::GraphInterface{V}, a, b) where {V} = (for e in edge_list(g); Graphs.degree(g, Graphs.src(e)) > 100 && error("x"); end; nothing)
c5(g, a, b) = f5(g, a, b); c5b(g, a, b) = f5b(g, a, b); c5c(g, a, b) = f5c(g, a, b); c5d(g, a, b) = f5d(g, a, b); c5e(g, a, b) = f5e(g, a, b)
c6(g, a, b) = f6(g, a, b); c7(g, a, b) = f7(g, a, b)
using NetworkDynamics: hasff, is_loopback
function ffcopy(g::GraphInterface{V}, vertexm, edgem) where {V}
    errorstring = ""
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    ERRORMSG = "Feed forward vertex models are only allowed as leave nodes (1 neighbor) \
                with single `LoopbackConnection` from satelite to cluster node! In other \
                scenarios can use `ff_to_constraint(vf)` on the vertex model to turn \
                feed forward outputs into algebraic states."
    # test all have one neighbor
    if any(n -> length(n) != 1, nbs)
        throw(ArgumentError(ERRORMSG))
    end

    # test all have loopback from ff vert to cluster
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    all(zip(ffvertices, only.(nbs))) do (src, dst)
        SimpleEdge{V}(src, dst) ∈ simpleedges
    end || throw(ArgumentError(ERRORMSG))

    # check that all looback edges have origin at leaf node
    for (i, e) in zip(eidx, simpleedges)
        if Graphs.degree(g, Graphs.src(e)) != 1
            throw(ArgumentError("All LoopbackConnection edges must originate from leaf nodes! \
                             Found at least one going from hub to leaf: $(edgem[i])"))
        end
    end
    nothing
end
cff(g, a, b) = ffcopy(g, a, b)

function v1(g::GraphInterface{V}, vertexm, edgem) where {V}
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    any(n -> length(n) != 1, nbs) && throw(ArgumentError("x"))
    nothing
end
function v2(g::GraphInterface{V}, vertexm, edgem) where {V}
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    all(zip(ffvertices, only.(nbs))) do (src, dst)
        SimpleEdge{V}(src, dst) ∈ simpleedges
    end || throw(ArgumentError("y"))
    nothing
end
function v2a(g::GraphInterface{V}, vertexm, edgem) where {V}
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    all(zip(ffvertices, only.(nbs))) do (s, d)
        SimpleEdge{V}(s, d) ∈ simpleedges
    end || throw(ArgumentError("y"))
    nothing
end
function v2b(g::GraphInterface{V}, vertexm, edgem) where {V}
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    all(zip(ffvertices, [only(n) for n in nbs])) do (src, dst)
        SimpleEdge{V}(src, dst) ∈ simpleedges
    end || throw(ArgumentError("y"))
    nothing
end
function v2c(g::GraphInterface{V}, vertexm, edgem) where {V}
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    all(zip(ffvertices, only.(nbs))) do (src, dst)
        SimpleEdge{Int}(src, dst) ∈ simpleedges
    end || throw(ArgumentError("y"))
    nothing
end
function v2d(g::GraphInterface{V}, vertexm, edgem) where {V}
    ffvertices = findall(hasff, vertexm)
    nbs = map(ffvertices) do i
        all_neighbor_list(g, V(i))
    end
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    all(zip(ffvertices, ffvertices)) do (src, dst)
        SimpleEdge{V}(src, dst) ∈ simpleedges
    end || throw(ArgumentError("y"))
    nothing
end

m1(g::GraphInterface{V}, a, b) where {V} = (x = map(i -> all_neighbor_list(g, V(i)), a); any(i -> SimpleEdge{V}(i, i) == SimpleEdge{V}(1, 1), a); nothing)
m2(g::GraphInterface{V}, a, b) where {V} = (x = map(i -> all_neighbor_list(g, V(i)), a); any(i -> i == 1, a); nothing)
m3(g::GraphInterface{V}, a, b) where {V} = (x = map(i -> nv(g) + i, a); any(i -> V(i) == one(V), a); nothing)
m4(g::GraphInterface{V}, a, b) where {V} = (x = map(i -> V(i), a); any(i -> V(i) == one(V), a); nothing)
m5(g::GraphInterface{V}, a, b) where {V} = (x = map(i -> nv(g) + i, a); any(i -> i == 1, a); nothing)
m6(g::GraphInterface{V}, a, b) where {V} = (x = map(i -> nv(g) + i, a); y = map(i -> ne(g) + i, a); nothing)
m7(g::GraphInterface{V}, a, b) where {V} = (vs = V.(a); nbs = map(i -> all_neighbor_list(g, i), vs); es = edge_list(g); all(zip(vs, vs)) do (s, d); SimpleEdge(s, d) ∈ es end; nothing)
cm1(g, a, b) = m1(g, a, b); cm2(g, a, b) = m2(g, a, b); cm3(g, a, b) = m3(g, a, b); cm4(g, a, b) = m4(g, a, b); cm5(g, a, b) = m5(g, a, b); cm6(g, a, b) = m6(g, a, b); cm7(g, a, b) = m7(g, a, b)

n1(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g); all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end || throw(ArgumentError("y")); nothing)
n2(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g); all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end; nothing)
n3(g::GraphInterface{V}, a, b) where {V} = (eidx = findall(is_loopback, b); es = edge_list(g)[eidx]; all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end; nothing)
n4(g::GraphInterface{V}, a, b) where {V} = (eidx = findall(is_loopback, b); es = edge_list(g); all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end; nothing)
n5(g::GraphInterface{V}, a, b) where {V} = (eidx = [5, 6]; es = edge_list(g)[eidx]; all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end; nothing)
n6(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g)[[5, 6]]; any(e -> e == SimpleEdge{V}(1, 1), es); nothing)
n7(g::GraphInterface{V}, a, b) where {V} = (es = edge_list(g)[[5, 6]]; any(e -> e == SimpleEdge(1, 1), es); nothing)
cn1(g, a, b) = n1(g, a, b); cn2(g, a, b) = n2(g, a, b); cn3(g, a, b) = n3(g, a, b); cn4(g, a, b) = n4(g, a, b); cn5(g, a, b) = n5(g, a, b); cn6(g, a, b) = n6(g, a, b); cn7(g, a, b) = n7(g, a, b)

n8(g::GraphInterface{V}, a, b) where {V} = (es = Base.inferencebarrier(edge_list(g)); all(zip(a, a)) do (s, d); SimpleEdge{V}(s, d) ∈ es end; nothing)
n9(g::GraphInterface{V}, a, b) where {V} = (es = Base.inferencebarrier(edge_list(g)); all(zip(a, a)) do (s, d); SimpleEdge(s, d) ∈ es end; nothing)
n10(g::GraphInterface{V}, a, b) where {V} = (eidx = findall(is_loopback, b); es = edge_list(g)[eidx]; all(zip(V.(a), V.(a))) do (s, d); SimpleEdge(s, d) ∈ es end; nothing)
n11(g::GraphInterface{V}, a, b) where {V} = (es = Base.inferencebarrier(edge_list(g)); any(e -> e == SimpleEdge{V}(1, 1), es); nothing)
n12(g::GraphInterface{V}, a, b) where {V} = (eidx = findall(is_loopback, b); x = eidx; nothing)
cn8(g, a, b) = n8(g, a, b); cn9(g, a, b) = n9(g, a, b); cn10(g, a, b) = n10(g, a, b); cn11(g, a, b) = n11(g, a, b)
cv2a(g, a, b) = v2a(g, a, b); cv2b(g, a, b) = v2b(g, a, b); cv2c(g, a, b) = v2c(g, a, b); cv2d(g, a, b) = v2d(g, a, b)
function v3(g::GraphInterface{V}, vertexm, edgem) where {V}
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    for (i, e) in zip(eidx, simpleedges)
        if Graphs.degree(g, Graphs.src(e)) != 1
            throw(ArgumentError("z $(edgem[i])"))
        end
    end
    nothing
end
function v4(g::GraphInterface{V}, vertexm, edgem) where {V}
    eidx = findall(is_loopback, edgem)
    simpleedges = edge_list(g)[eidx]
    for (i, e) in zip(eidx, simpleedges)
        Graphs.degree(g, Graphs.src(e)) != 1 && throw(ArgumentError("z"))
    end
    nothing
end
function v5(g::GraphInterface{V}, vertexm, edgem) where {V}
    for e in edge_list(g)
        Graphs.degree(g, Graphs.src(e)) != 1 && throw(ArgumentError("z $(edgem[1])"))
    end
    nothing
end
cv1(g, a, b) = v1(g, a, b); cv2(g, a, b) = v2(g, a, b); cv3(g, a, b) = v3(g, a, b); cv4(g, a, b) = v4(g, a, b); cv5(g, a, b) = v5(g, a, b)
end
g = watts_strogatz(20, 4, 0.2; seed = 42)
vm = [VertexModel(f = (du, u, i, p, t) -> nothing, g = 1, sym = [:x], insym = [:i]) for _ in 1:2]
for (name, f, args) in (("c1 g::AbstractGraph, one arg", R.c1, (g,)), ("c2 g::AbstractGraph, untyped a, b", R.c2, (g, [1, 2], [3])),
                        ("c3 … with a closure over g", R.c3, (g, [1, 2], [3])), ("c2u untyped caller", R.c2u, (g, [1, 2], [3])),
                        ("c4 bound a::Vector{<:VertexModel}", R.c4, (g, vm, [3])), ("c4u untyped caller", R.c4u, (g, vm, [3])),
                        ("c4v caller a::Vector{VertexModel}", R.c4v, (g, vm, [3])), ("c4w caller a::Union{…}", R.c4w, (g, vm, [3])),
                        ("c5 do-block (s, d) SimpleEdge{V}", R.c5, (g, [1, 2], [3])), ("c5b do-block SimpleEdge{Int}", R.c5b, (g, [1, 2], [3])),
                        ("c5c closure t -> SimpleEdge{V}", R.c5c, (g, [1, 2], [3])), ("c5d closure e -> SimpleEdge{V}(1, 2)", R.c5d, (g, [1, 2], [3])),
                        ("c5e closure over W = V", R.c5e, (g, [1, 2], [3])),
                        ("c6 throw with interpolation", R.c6, (g, [1, 2], [3])), ("c7 loop with degree, src", R.c7, (g, [1, 2], [3])))
    r = try string(f(args...)) catch err; string("FAILS ", nameof(typeof(err)), ": ", first(sprint(showerror, err), 100)) end
    println("G3probe ", name, ": ", r)
end

# the function itself, on ffnet's graph and models (built with the check off), from a typed caller
include(joinpath(@__DIR__, "rhs_check_nets.jl"))
const ND = NetworkDynamics
ND.CHECK_COMPONENT[] = false
nw0 = ffnet()
ND.CHECK_COMPONENT[] = true
gg = nw0.im.g
callff(g, vm, em) = ND.check_feedforward_leaves(g, vm, em)
for f in (R.cm1, R.cm2, R.cm3, R.cm4, R.cm5, R.cm6, R.cm7, R.cn1, R.cn2, R.cn3, R.cn4, R.cn5, R.cn6, R.cn7, R.cn8, R.cn9, R.cn10, R.cn11)
    r = try string(f(gg, [5, 6], nw0.im.edgem)) catch err; string("FAILS ", nameof(typeof(err)), ": ", first(sprint(showerror, err), 80)) end
    println("G3probe ", f, ": ", r)
end
println("G3probe findall(is_loopback, ::Vector{EdgeModel}) inferred: ", Base.return_types(findall, (typeof(NetworkDynamics.is_loopback), Vector{EdgeModel})))
println("G3probe EdgeModel isa UnionAll: ", EdgeModel isa UnionAll, "; isconcretetype(EdgeModel): ", isconcretetype(EdgeModel))
for f in (R.cv1, R.cv2, R.cv3, R.cv4, R.cv5, R.cv2a, R.cv2b, R.cv2c, R.cv2d)
    r = try string(f(gg, nw0.im.vertexm, nw0.im.edgem)) catch err; string("FAILS ", nameof(typeof(err)), ": ", first(sprint(showerror, err), 80)) end
    println("G3probe ", f, ": ", r)
end
try
    println("G3probe a copy of check_feedforward_leaves in a script's trait module, on ffnet: ", R.cff(gg, nw0.im.vertexm, nw0.im.edgem))
catch err
    println("G3probe the copy FAILS: ", sprint(showerror, err))
end
try
    println("G3probe check_feedforward_leaves on ffnet: ", callff(gg, nw0.im.vertexm, nw0.im.edgem))
catch err
    println("G3probe check_feedforward_leaves on ffnet FAILS: ", sprint(showerror, err))
    Base.show_backtrace(stdout, catch_backtrace()); println()
end
