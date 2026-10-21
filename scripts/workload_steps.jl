# The workload's steps (the P1 plan, writeup/plans/2026-10-21-ndport-workload.md §2): swing equations
# on a seeded Watts–Strogatz graph, a fixed point and its linear stability, a cascade of line trips by
# component callbacks, Tsit5 and Rodas5P, symbolic indexing, a GraphMakie PNG, a figure driven by
# Observables while the integrator steps, then the equations changed.
# Each step returns its result; its digest (`D <pass> <step> key=value ...`: exact fields as hashes and
# integers, values to 10 digits) is printed by `digest_<step>`, outside the timed window.
# Loaded by workload.jl after the packages.
module NDW

using NetworkDynamics, Graphs, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
import SymbolicIndexingInterface as SII
using CairoMakie, GraphMakie, Observables
using GraphMakie.NetworkLayout: Spring
using Printf

const OUT = joinpath(@__DIR__, "..", "out")
const PASS = Ref("first")
const SOLVE_KW = (; abstol = 1e-8, reltol = 1e-6)
const TIMES = [0.5, 1.0, 1.5, 2.0, 3.0, 4.5, 6.0]
const CRANGE = (-3.0, 3.0)                      # the colour range of ω (islands drift after the cascade)

# ---- digests ----------------------------------------------------------------------------------
bits(x) = string(hash(reinterpret(UInt64, collect(Float64, x))); base = 16)
num(x::Real) = @sprintf("%.10g", x)
num(xs) = join(num.(xs), ",")
digest(step, fields...) = println("D ", PASS[], " ", step, " ", join(("$k=$v" for (k, v) in fields), " "))

# ---- a. components ------------------------------------------------------------------------------
function swing!(dv, v, esum, p, t)
    P, I, γ = p
    dv[1] = v[2]
    dv[2] = (P - γ * v[2] + esum[1]) / I
    nothing
end
function swing2!(dv, v, esum, p, t)               # the changed equations: a cubic damping
    P, I, γ, κ = p
    dv[1] = v[2]
    dv[2] = (P - γ * v[2] - κ * v[2]^3 + esum[1]) / I
    nothing
end
line!(e, v_s, v_d, (K,), t) = (e[1] = K * sin(v_s[1] - v_d[1]); nothing)

function step_a(model::Symbol)
    vertex = model === :swing ?
        VertexModel(f = swing!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1]) :
        VertexModel(f = swing2!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1, :κ => 0.5])
    edge = EdgeModel(g = AntiSymmetric(line!), outsym = :P, psym = [:K => 6.0, :limit => 1.0])
    (; vertex, edge)
end
digest_a(r) = digest("a", :vdim => dim(r.vertex), :vpdim => pdim(r.vertex), :edim => dim(r.edge), :epdim => pdim(r.edge))

# ---- b. the network -----------------------------------------------------------------------------
function step_b(r)
    g = watts_strogatz(20, 4, 0.2; seed = 42)
    Network(g, r.vertex, r.edge; dealias = true)
end
function digest_b(nw)
    g = get_graph(nw)
    es = [(src(e), dst(e)) for e in edges(g)]
    digest("b", :nv => nv(g), :ne => ne(g), :connected => is_connected(g), :edges => string(hash(es); base = 16),
           :dim => dim(nw), :pdim => pdim(nw))
end

# ---- c. state: parameters, the fixed point, its linear stability --------------------------------
function step_c(nw; γ = 0.1)
    for i in 1:nv(get_graph(nw))
        set_default!(nw, VIndex(i, :P_ref), isodd(i) ? 1.0 : -1.0)
        set_default!(nw, VIndex(i, :γ), γ)
    end
    u0 = find_fixpoint(nw)
    set_defaults!(nw, u0)
    s = NWState(nw)
    λ = jacobian_eigenvals(s)
    (; s, fix = isfixpoint(s), λmax = maximum(real, λ))
end
digest_c(r) = digest("c", :u => bits(uflat(r.s)), :p => bits(pflat(r.s)), :δ => num(r.s.v[1:5, :δ]),
                     :Pmax => num(maximum(abs, r.s.e[:, :P])), :fix => r.fix, :λmax => num(r.λmax))

# ---- d. solve, with a cascade of line trips -----------------------------------------------------
function step_d(nw, s)
    trips = Tuple{Int,Float64}[]
    cond = ComponentCondition([:P], [:limit]) do u, p, t
        abs(u[:P]) - p[:limit]
    end
    affect = ComponentAffect([], [:K]) do u, p, ctx
        push!(trips, (ctx.eidx, ctx.integrator.t))
        p[:K] = 0
    end
    for i in 1:ne(get_graph(nw))
        set_callback!(nw[EIndex(i)], ContinuousComponentCallback(cond, affect))
    end
    first_trip = argmax(abs.(s.e[:, :P]))              # the most loaded line fails first
    add_callback!(nw[EIndex(first_trip)], PresetTimeComponentCallback(1.0, affect))
    prob = ODEProblem(nw, NWState(nw), (0.0, 6.0))
    fresh() = remake(prob; p = copy(prob.p))           # the callbacks write K = 0 into the parameters
    sol = solve(fresh(), Tsit5(); SOLVE_KW...)
    ttrips = copy(trips); empty!(trips)
    rsol = solve(fresh(), Rodas5P(); SOLVE_KW...)
    (; prob, sol, rsol, ttrips, rtrips = copy(trips))
end
function digest_d(r)
    ω = r.sol(TIMES; idxs = VIndex(2, :ω)).u
    ωr = r.rsol(TIMES; idxs = VIndex(2, :ω)).u
    digest("d", :retcode => r.sol.retcode, :rretcode => r.rsol.retcode, :trips => join(first.(r.ttrips), ","),
           :rtrips => join(first.(r.rtrips), ","), :ttrips => num(last.(r.ttrips)), :trtrips => num(last.(r.rtrips)),
           :ω2 => num(ω), :ω2r => num(ωr), :sol => bits(reduce(vcat, r.sol.u)), :rsol => bits(reduce(vcat, r.rsol.u)),
           :nsteps => length(r.sol.t), :rnsteps => length(r.rsol.t))
end

# ---- e. access by symbolic index ----------------------------------------------------------------
function step_e(nw, sol)
    ωall = sol(TIMES; idxs = vidxs(nw, :, :ω))
    P2 = sol(TIMES; idxs = EIndex(2, :P))
    s3 = NWState(sol, 3.0)
    getP = SII.getu(sol, eidxs(nw, :, :P))
    (; ωsum = [sum(u) for u in ωall.u], P2 = P2.u, P3 = s3.e[1:6, :P], K3 = s3.p.e[1:6, :K], Pend = getP(sol)[end][1:6])
end
digest_e(r) = digest("e", :ωsum => num(r.ωsum), :P2 => num(r.P2), :P3 => num(r.P3), :K3 => num(r.K3), :Pend => num(r.Pend))

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

# ---- the passes ---------------------------------------------------------------------------------
"Steps a–g for one model; `timed(name, f)` runs and times each step, the digests outside it."
function run_pass(timed, pass, model; γ = 0.1)
    PASS[] = pass
    a = timed("a", () -> step_a(model)); digest_a(a)
    nw = timed("b", () -> step_b(a)); digest_b(nw)
    c = timed("c", () -> step_c(nw; γ)); digest_c(c)
    d = timed("d", () -> step_d(nw, c.s)); digest_d(d)
    e = timed("e", () -> step_e(nw, d.sol)); digest_e(e)
    f = timed("f", () -> step_f(nw, d.sol, model)); digest_f(f)
    g = timed("g", () -> step_g(nw, d.prob, model)); digest_g(g)
    (nw, d.prob)
end

"The control: the parameters changed on the problem of the first pass (`remake`), no new types."
function run_params(timed, nw, prob)
    PASS[] = "params"
    d = timed("d", () -> begin
        p = copy(prob.p); s = NWParameter(nw, p); s.v[:, :γ] .= 0.2
        prob2 = remake(prob; p = pflat(s))
        (; prob = prob2, sol = solve(prob2, Tsit5(); SOLVE_KW...))
    end)
    digest("d", :retcode => d.sol.retcode, :ω2 => num(d.sol(TIMES; idxs = VIndex(2, :ω)).u))
    e = timed("e", () -> step_e(nw, d.sol)); digest_e(e)
    f = timed("f", () -> step_f(nw, d.sol, :params)); digest_f(f)
    g = timed("g", () -> step_g(nw, d.prob, :params)); digest_g(g)
    nothing
end

end # module
