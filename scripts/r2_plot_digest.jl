# R2 (E-240), the Makie side: the workload's two GraphMakie plots (steps f and g, `workload_plot.jl`) with the same
# inputs in setting M (upstream GraphMakie and CairoMakie, env_merged) and on the ports (GraphMakie's branch `ports`
# over MakieCompat and TraitMakie, env_r2plot). The inputs are fixed numbers, not the simulation's (the plots, not the
# solver, are compared). Prints digest lines `P <step> <what> <value>`: node positions, the colours the plot hands its
# drawing (RGBA × 255, rounded), the edges' line data, step g's line and listeners. PNGs cannot be equal (different
# backends); they are saved for a look.
#     julia --project=env_merged scripts/r2_plot_digest.jl M <out dir>
#     julia --project=env_r2plot scripts/r2_plot_digest.jl PT <out dir>
const SETTING = ARGS[1]
const OUT = ARGS[2]; mkpath(OUT)
if SETTING == "M"
    using CairoMakie, GraphMakie, Observables, Graphs
else
    using MakieCompat, GraphMakie, Observables, Graphs
end
using GraphMakie.NetworkLayout: Spring

const CRANGE = (-3.0, 3.0)
g = watts_strogatz(20, 4, 0.2; seed = 42)
ωf = [2.5 * sin(0.7i) for i in 1:nv(g)]
Pf = [1.2 * cos(0.3e) for e in 1:ne(g)]
ωg(k) = [2.5 * sin(0.7i + 0.4k) for i in 1:nv(g)]

r4(x) = round(Float64(x); digits = 4)
pts(ps) = join((string("(", r4(p[1]), ",", r4(p[2]), ")") for p in ps), " ")
c255(c) = string("(", join((round(Int, 255 * Float64(x)) for x in c), ","), ")")
line(step, what, v) = println("P ", step, " ", what, " ", v)

if SETTING == "M"
    # Makie's own conversion of numbers to colours, from the plot's own attribute values (numbers_to_colors)
    function mcolors(plt)
        c = plt[:color][]
        c isa AbstractVector{<:Real} || return fill((0.0, 0.0, 0.0, 1.0), 1)
        cr = plt[:colorrange][]
        cr = cr === Makie.automatic || cr === nothing ? Makie.extrema_nan(c) : cr
        cs = Makie.numbers_to_colors(c, Makie.to_colormap(plt[:colormap][]), identity, Vec2f(cr...),
                                     Makie.automatic, Makie.automatic, Makie.RGBAf(0, 0, 0, 0), true)
        return [(Makie.red(x), Makie.green(x), Makie.blue(x), Makie.alpha(x)) for x in cs]
    end
    nodecolors(p) = mcolors(get_node_plot(p))
    function edgecolors(p)
        ep = get_edge_plot(p)
        cs = mcolors(ep.plots[1])                    # per point; an edge's colour at its first point
        return [cs[first(r)] for r in ep[:ranges][]]
    end
else
    const PC = MakieCompat.PC
    rgbas(cs, n) = [PC.rgba(cs, i) for i in 1:n]
    # the colours the bridge hands the core's primitives
    nodecolors(p) = (c = get_node_plot(p); rgbas(MakieCompat._leafcolor(c, :black, nothing), length(MakieCompat.resolve(c.pos))))
    function edgecolors(p)
        c = getfield(get_edge_plot(p), :children)[1]
        return [PC.rgba(MakieCompat._leafcolor(c, :black, r), 1) for r in MakieCompat._runs(MakieCompat.resolve(c.pos))]
    end
end

# ---- f. a GraphMakie plot -----------------------------------------------------------------------
fig, ax, p = graphplot(g; layout = Spring(seed = 1), node_color = ωf, node_size = 14, edge_color = abs.(Pf), edge_width = 2,
                       node_attr = (; colorrange = CRANGE, colormap = :balance))
hidedecorations!(ax)
save(joinpath(OUT, "graph-$SETTING.png"), fig)
line("f", "type", nameof(typeof(fig)))
line("f", "pos", pts(p[:node_pos][]))
eps = get_edge_plot(p)[:points][]
line("f", "edgepoints", string(length(eps), " nan ", count(q -> any(isnan, q), eps)))
line("f", "edgepoints1-6", pts(eps[1:6]))
line("f", "nodecolors", join(c255.(nodecolors(p)), " "))
line("f", "edgecolors", join(c255.(edgecolors(p)), " "))

# ---- g. a figure driven by Observables (a stand-in for the integrator: fixed frames) ----------------
sel = Observable(2)
colors = Observable(ωg(0))
ts = Observable(Float64[0.0])
hist = Observable(Vector{Float64}[copy(colors[])])
lifted = lift((h, i) -> Point2f.(ts[], getindex.(h, i)), hist, sel)
ncalls = Ref(0)
on(_ -> ncalls[] += 1, colors)
fig2 = Figure(size = (900, 400))
ax1 = Axis(fig2[1, 1]); hidedecorations!(ax1)
p2 = graphplot!(ax1, g; layout = Spring(seed = 1), node_color = colors, node_size = 14,
                node_attr = (; colorrange = CRANGE, colormap = :balance))
ax2 = Axis(fig2[1, 2]; xlabel = "t", ylabel = "ω")
lines!(ax2, lifted)
limits!(ax2, 0, 6, -4, 4)
frames = 0
for k in 1:10
    ω = ωg(k)
    push!(ts[], 0.6k)
    hist[] = push!(hist[], copy(ω))
    colors[] = ω
    if k % 3 == 0
        save(joinpath(OUT, "live-$SETTING-$k.png"), fig2); global frames += 1
        line("g", "nodecolors-$k", join(c255.(nodecolors(p2))[1:5], " "))
    end
end
sel[] = 3
save(joinpath(OUT, "live-$SETTING-sel.png"), fig2); frames += 1
line("g", "nodecolors-sel", join(c255.(nodecolors(p2))[1:5], " "))
line("g", "line", string(length(lifted[]), " last ", pts(lifted[][end:end])))
line("g", "listeners", ncalls[])
line("g", "frames", frames)
