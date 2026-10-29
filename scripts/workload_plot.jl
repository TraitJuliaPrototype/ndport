# The workload's plotting steps f and g (the P1 plan §2.2), included into module NDW
# (workload_steps.jl) once CairoMakie, GraphMakie and Observables are loaded.
@static if ON_PORTS
    using MakieCompat, GraphMakie, Observables
else
    using CairoMakie, GraphMakie, Observables
end
using GraphMakie.NetworkLayout: Spring

# R5 (E-246): the graph plots' digests of E-240 (`scripts/r2_plot_digest.jl`), from the simulation's output, in the
# variant for the ports: `P <pass> <step> <what> <value>`: node positions, the colours handed to the drawing
# (RGBA × 255, rounded), the edges' line data.
r4(x) = round(Float64(x); digits = 4)
pts(ps) = join((string("(", r4(p[1]), ",", r4(p[2]), ")") for p in ps), " ")
c255(c) = string("(", join((round(Int, 255 * Float64(x)) for x in c), ","), ")")
pline(step, what, v) = API == "ports" && (println("P ", PASS[], " ", step, " ", what, " ", v); flush(stdout))
@static if ON_PORTS
    const PC = MakieCompat.PC
    rgbas(cs, n) = [PC.rgba(cs, i) for i in 1:n]
    nodecolors(p) = (c = get_node_plot(p); rgbas(MakieCompat._leafcolor(c, :black, nothing), length(MakieCompat.resolve(c.pos))))
    function edgecolors(p)
        c = getfield(get_edge_plot(p), :children)[1]
        return [PC.rgba(MakieCompat._leafcolor(c, :black, r), 1) for r in MakieCompat._runs(MakieCompat.resolve(c.pos))]
    end
else
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
        cs = mcolors(ep.plots[1])
        return [cs[first(r)] for r in ep[:ranges][]]
    end
end
function plot_digest_f(p)
    API == "ports" || return nothing
    pline("f", "pos", pts(p[:node_pos][]))
    eps = get_edge_plot(p)[:points][]
    pline("f", "edgepoints", string(length(eps), " nan ", count(q -> any(isnan, q), eps)))
    pline("f", "edgepoints1-6", pts(eps[1:6]))
    pline("f", "nodecolors", join(c255.(nodecolors(p)), " "))
    pline("f", "edgecolors", join(c255.(edgecolors(p)), " "))
    nothing
end

const CRANGE = (-3.0, 3.0)                      # the colour range of ω (islands drift after the cascade)

# ---- f. a GraphMakie plot -----------------------------------------------------------------------
function step_f(nw, sol, tag)
    s = NWState(sol, sol.t[end])
    fig, ax, p = graphplot(get_graph(nw); layout = Spring(seed = 1), node_color = s.v[:, :ω], node_size = 14,
                           edge_color = abs.(s.e[:, :P]), edge_width = 2,
                           node_attr = (; colorrange = CRANGE, colormap = :balance))
    hidedecorations!(ax)
    file = joinpath(OUT, "graph-$tag-$(PASS[]).png")
    save(file, fig)
    (; pos = p[:node_pos][], colors = s.v[:, :ω], file, p)
end
pngsize(file) = (b = read(file, 24); Int.(ntoh.(reinterpret(UInt32, b[17:24]))))   # width, height from the header
function digest_f(r)
    plot_digest_f(r.p)
    digest("f", :pos => num(round.(Float64.(reduce(vcat, collect.(r.pos[1:3]))); digits = 4)),
           :colors => num(r.colors[1:5]), :pixels => join(pngsize(r.file), "x"), :pngbytes => filesize(r.file))
end

# ---- g. a figure driven by Observables while the integrator steps -------------------------------
function step_g(nw, prob, tag)
    integ = init(remake(prob; p = copy(prob.p)), Tsit5(); SOLVE_KW...)
    sel = Observable(2)                                  # the vertex whose trajectory is shown
    colors = Observable(NWState(integ).v[:, :ω])
    ts = Observable(Float64[integ.t])
    hist = Observable(Vector{Float64}[copy(colors[])])   # every vertex's ω at every frame
    line = lift((h, i) -> Point2f.(ts[], getindex.(h, i)), hist, sel)
    ncalls = Ref(0)
    on(_ -> ncalls[] += 1, colors)
    fig = Figure(size = (900, 400))
    ax1 = Axis(fig[1, 1]); hidedecorations!(ax1)
    p2 = graphplot!(ax1, get_graph(nw); layout = Spring(seed = 1), node_color = colors, node_size = 14,
                    node_attr = (; colorrange = CRANGE, colormap = :balance))
    pdig = String[]                                      # R5: the plot's digests, printed outside the timed window
    ax2 = Axis(fig[1, 2]; xlabel = "t", ylabel = "ω")
    lines!(ax2, line)
    limits!(ax2, 0, 6, -4, 4)
    frames = 0
    for k in 1:10
        step!(integ, 0.6, true)
        ω = NWState(integ).v[:, :ω]
        push!(ts[], integ.t)                             # ts first: the line reads ts[] when hist fires
        hist[] = push!(hist[], copy(ω))
        colors[] = ω
        if k % 3 == 0
            save(joinpath(OUT, "live-$tag-$(PASS[])-$k.png"), fig); frames += 1
            API == "ports" && push!(pdig, string("nodecolors-$k ", join(c255.(nodecolors(p2))[1:5], " ")))
        end
    end
    sel[] = 3                                            # another trajectory, from the kept history
    save(joinpath(OUT, "live-$tag-$(PASS[])-sel.png"), fig); frames += 1
    if API == "ports"
        push!(pdig, string("nodecolors-sel ", join(c255.(nodecolors(p2))[1:5], " ")))
        push!(pdig, string("line ", length(line[]), " last ", pts(line[][end:end])))
    end
    (; t = integ.t, ω = colors[], line = line[], listeners = ncalls[], frames, pdig)
end
digest_g(r) = (foreach(l -> pline("g", split(l, ' '; limit = 2)...), r.pdig); digest_g0(r))
digest_g0(r) = digest("g", :t => num(r.t), :ωend => num(r.ω[1:5]), :line => length(r.line),
                     :sel3 => num(r.line[end][2]), :listeners => r.listeners, :frames => r.frames)
