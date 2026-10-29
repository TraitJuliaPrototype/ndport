# R2 (E-240), the Makie side: GraphMakie's features beyond the workload's two plots, on the ports (env_r2plot): which
# draw, and where each that does not stops. Prints `R2 probe <what> ok|FAIL <exception>: <message>`.
#     julia --project=env_r2plot scripts/r2_leaves_probe.jl <out dir>
using MakieCompat, GraphMakie, Graphs
using GraphMakie.NetworkLayout: Spring
const OUT = ARGS[1]; mkpath(OUT)
function attempt(what, f)
    try
        Base.invokelatest(f)
        println("R2 probe ", what, " ok")
    catch err
        println("R2 probe ", what, " FAIL ", nameof(typeof(err)), ": ", first(first(split(sprint(showerror, err), '\n')), 200))
    end
    flush(stdout)
end
g = watts_strogatz(20, 4, 0.2; seed = 42)
png(name) = joinpath(OUT, "probe-$name.png")
attempt("node labels (text! leaf)", () -> save(png("nlabels"), graphplot(g; layout = Spring(seed = 1), nlabels = string.(1:nv(g)))))
attempt("edge labels (text! leaf, to_px)", () -> save(png("elabels"), graphplot(g; layout = Spring(seed = 1), elabels = string.(1:ne(g)))))
attempt("per-edge widths and colours by name", () ->
    save(png("edgevec"), graphplot(g; layout = Spring(seed = 1), edge_width = collect(1.0:ne(g)) ./ 20, edge_color = :gray)))
attempt("node markers by name", () -> save(png("markers"), graphplot(g; layout = Spring(seed = 1), node_marker = :rect, node_size = 10)))
attempt("a layout given as points", () -> save(png("layoutvec"), graphplot(g; layout = Spring(seed = 1)(g))))
attempt("attributes changed after the plot (p.node_color, p.layout)", () -> begin
    fig, ax, p = graphplot(g; layout = Spring(seed = 1))
    p.node_color[] = [isodd(i) ? :red : :blue for i in 1:nv(g)]
    p.layout = Spring(seed = 2)
    save(png("changed"), fig)
end)
attempt("linesegments! (user API)", () -> begin
    fig = Figure(); ax = Axis(fig[1, 1])
    linesegments!(ax, Point2f[(0, 0), (1, 1), (1, 0), (2, 1)]; color = :red)
    save(png("linesegments"), fig)
end)
attempt("inner labels (ilabels: text bounding boxes)", () -> save(png("ilabels"), graphplot(g; layout = Spring(seed = 1), ilabels = string.(1:nv(g)))))
attempt("a directed graph (arrows: a Char marker, rotated)", () -> save(png("directed"), graphplot(SimpleDiGraph(g); layout = Spring(seed = 1))))
attempt("curved edges (Bézier paths)", () -> save(png("curved"), graphplot(g; layout = Spring(seed = 1), curve_distance = 0.3, curve_distance_usage = true)))
attempt("a dashed edge style", () -> save(png("dashed"), graphplot(g; layout = Spring(seed = 1), edge_linestyle = :dash)))
