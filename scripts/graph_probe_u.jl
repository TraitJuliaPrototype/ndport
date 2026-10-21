# G0 (a) and (d) of the graph plan: included by graph_probe.jl in setting U (top level: `using`).
using NetworkDynamics
include(joinpath(@__DIR__, "rhs_check_nets.jl"))       # swing!, line! (tier S's models)
vertex = VertexModel(f = swing!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1])
edge = EdgeModel(g = AntiSymmetric(line!), outsym = :P, psym = [:K => 6.0, :limit => 1.0])
netS(x) = Network(x, vertex, edge; dealias = true)
println("# G0 (a) upstream ND ", pkgversion(NetworkDynamics), " Graphs ", pkgversion(Graphs))
for (name, x) in (("SimpleGraph{Int64}", g), ("SimpleDiGraph{Int64}", d), ("GenericGraph", generic_graph(g)),
                  ("GenericDiGraph", generic_graph(d)), ("SimpleGraph{Int32}", SimpleGraph{Int32}(g)))
    try
        nw = netS(x)
        println("a ", name, " builds: nv=", nv(nw.im.g), " ne=", ne(nw.im.g), " dim=", dim(nw))
    catch err
        println("a ", name, " FAILS: ", nameof(typeof(err)), ": ", short(err))
        println("a ", name, "   frames: ", frames(catch_backtrace()))
    end
end
# the feed-forward check (construction.jl:66-96) on a GenericDiGraph: ffnet's graph and models
let gg = SimpleDiGraph(6)
    for (s, t) in ((1, 2), (2, 3), (3, 4), (4, 1), (5, 1), (6, 2)); add_edge!(gg, s, t); end
    nw0 = ffnet()
    for (name, x) in (("ff SimpleDiGraph", gg), ("ff GenericDiGraph", generic_graph(gg)))
        try
            Network(x, copy.(nw0.im.vertexm), copy.(nw0.im.edgem))
            println("a ", name, " builds")
        catch err
            println("a ", name, " FAILS: ", nameof(typeof(err)), ": ", short(err))
            println("a ", name, "   frames: ", frames(catch_backtrace()))
        end
    end
end

println("# G0 (d) GraphMakie on a GenericGraph; digest_b's reads")
gg = generic_graph(g)
println("d digest_b: nv=", nv(gg), " ne=", ne(gg), " connected=", is_connected(gg), "/", is_connected(g),
        " edges equal=", pairs_of(gg) == pairs_of(g))
using CairoMakie, GraphMakie
using GraphMakie.NetworkLayout: Spring
for (name, x) in (("SimpleGraph", g), ("GenericGraph", gg), ("GenericDiGraph", generic_graph(d)))
    try
        fig, ax, p = graphplot(x; layout = Spring(seed = 1), node_color = collect(range(-1, 1; length = nv(x))),
                               node_size = 14, edge_color = collect(range(0, 1; length = ne(x))), edge_width = 2,
                               node_attr = (; colorrange = (-3.0, 3.0), colormap = :balance))
        img = CairoMakie.colorbuffer(fig)
        pos = p[:node_pos][]
        println("d graphplot ", name, " renders: ", size(img), " pos[1:2]=", pos[1:2])
        fig2 = Figure(); ax2 = Axis(fig2[1, 1])
        graphplot!(ax2, x; layout = Spring(seed = 1), node_color = Observable(zeros(nv(x))))
        println("d graphplot! ", name, " renders: ", size(CairoMakie.colorbuffer(fig2)))
    catch err
        println("d graphplot ", name, " FAILS: ", nameof(typeof(err)), ": ", short(err))
        println("d graphplot ", name, "   frames: ", frames(catch_backtrace(); n = 6))
    end
end
