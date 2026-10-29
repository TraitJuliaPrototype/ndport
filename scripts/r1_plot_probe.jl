# R1 (E-237), part 3: the workload's plotting calls outside GraphMakie's recipe (steps f and g), against TraitMakie
# and MakieCompat (env_r1plot). Each call is tried; prints `R1 plot <what> ok|FAIL …`.
#     julia --project=env_r1plot scripts/r1_plot_probe.jl <out dir>
using TraitMakie, MakieCompat, Observables, NetworkLayout, Graphs
using NetworkLayout: GeometryBasics
using .GeometryBasics: Point2f   # the ecosystem's points (NetworkLayout returns them), not MakieCompat's
const OUT = ARGS[1]; mkpath(OUT)
function attempt(what, f)
    try
        v = Base.invokelatest(f)
        println("R1 plot ", what, " ok"); flush(stdout)
        return v
    catch err
        msg = first(split(sprint(showerror, err), '\n'))
        println("R1 plot ", what, " FAIL ", nameof(typeof(err)), ": ", first(msg, 260)); flush(stdout)
        return nothing
    end
end
g = watts_strogatz(20, 4, 0.2; seed = 42)
pos = attempt("Spring(seed = 1)(g) (NetworkLayout)", () -> Spring(seed = 1)(g))
pos === nothing || println("R1 plot info layout eltype ", eltype(pos))
ω = collect(range(-2.0, 2.0; length = 20))
# step f's leaves as GraphMakie would draw them, through TraitMakie's API
fig = attempt("Figure()", () -> Figure())
ax = attempt("Axis(fig[1, 1])", () -> Axis(fig[1, 1]))
attempt("scatter!(ax, GeometryBasics points)", () -> scatter!(ax, pos))
attempt("scatter!(ax, xs, ys)", () -> scatter!(ax, first.(pos), last.(pos)))
attempt("scatter!(ax, xs, ys; color = numbers, colormap = :balance, colorrange)", () ->
    scatter!(ax, first.(pos), last.(pos); color = ω, colormap = :balance, colorrange = (-3.0, 3.0), markersize = 14))
segs = [p for e in edges(g) for p in (pos[src(e)], pos[dst(e)], Point2f(NaN, NaN))]
attempt("lines!(ax, points with NaN breaks)", () -> lines!(ax, first.(segs), last.(segs)))
attempt("lines!(ax, …; color = a vector per point)", () -> lines!(ax, first.(segs), last.(segs); color = rand(length(segs))))
attempt("linesegments!(ax, …)", () -> getfield(TraitMakie, :linesegments!)(ax, segs))
attempt("hidedecorations!(ax)", () -> getfield(TraitMakie, :hidedecorations!)(ax))
attempt("save(png, fig)", () -> save(joinpath(OUT, "probe-f.png"), fig))
# step g's figure
fig2 = attempt("Figure(size = (900, 400))", () -> Figure(size = (900, 400)))
ax2 = attempt("Axis(fig[1, 2]; xlabel, ylabel)", () -> Axis(fig2[1, 2]; xlabel = "t", ylabel = "ω"))
attempt("limits!(ax2, 0, 6, -4, 4)", () -> getfield(TraitMakie, :limits!)(ax2, 0, 6, -4, 4))
hist = Observable([[0.0, 1.0]])
ts = Observable([0.0])
line = attempt("lift(f, obs...)", () -> getfield(TraitMakie, :lift)((h, i) -> Point2f.(ts[], getindex.(h, i)), hist, Observable(2)))
line2 = map((h) -> Point2f.(ts[], getindex.(h, 2)), hist)        # Observables' own `map`
attempt("lines!(ax2, Observable{Vector{Point2f}})", () -> lines!(ax2, line2))
cols = Observable(ω)
attempt("scatter!(ax, …; color = Observable)", () -> scatter!(ax, first.(pos), last.(pos); color = cols, colormap = :balance, colorrange = (-3.0, 3.0)))
attempt("on(f, obs)", () -> on(_ -> nothing, cols))
attempt("obs[] = v; save (the figure follows)", () -> (cols[] = reverse(ω); save(joinpath(OUT, "probe-g.png"), fig)))
attempt("graphplot (TraitMakie)", () -> getfield(TraitMakie, :graphplot))
