# The workload's plotting steps f and g (the P1 plan §2.2), included into module NDW
# (workload_steps.jl) once CairoMakie, GraphMakie and Observables are loaded.
using CairoMakie, GraphMakie, Observables
using GraphMakie.NetworkLayout: Spring

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
    (; pos = p[:node_pos][], colors = s.v[:, :ω], file)
end
pngsize(file) = (b = read(file, 24); Int.(ntoh.(reinterpret(UInt32, b[17:24]))))   # width, height from the header
function digest_f(r)
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
    graphplot!(ax1, get_graph(nw); layout = Spring(seed = 1), node_color = colors, node_size = 14,
               node_attr = (; colorrange = CRANGE, colormap = :balance))
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
        end
    end
    sel[] = 3                                            # another trajectory, from the kept history
    save(joinpath(OUT, "live-$tag-$(PASS[])-sel.png"), fig); frames += 1
    (; t = integ.t, ω = colors[], line = line[], listeners = ncalls[], frames)
end
digest_g(r) = digest("g", :t => num(r.t), :ωend => num(r.ω[1:5]), :line => length(r.line),
                     :sel3 => num(r.line[end][2]), :listeners => r.listeners, :frames => r.frames)
