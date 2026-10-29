# The workload's steps (the P1 plan, writeup/plans/2026-10-21-ndport-workload.md §2): swing equations
# on a seeded Watts–Strogatz graph, a fixed point and its linear stability, a cascade of line trips by
# component callbacks, Tsit5 and Rodas5P, symbolic indexing, a GraphMakie PNG, a figure driven by
# Observables while the integrator steps, then the equations changed.
# Each step returns its result; its digest (`D <pass> <step> key=value ...`: exact fields as hashes and
# integers, values to 10 digits) is printed by `digest_<step>`, outside the timed window.
# Loaded by workload.jl after the packages; the plotting steps f and g are in workload_plot.jl, included
# into this module once Makie is loaded (so that the plotting packages can load after the simulation).
# NDW_API=ports (R5, E-246): the variant for the trait ports, the same in PT and in its reference U′: Rodas5 for
# Rodas5P, the values at TIMES by `saveat` (both solves), `getu` for `SII.getu`; the network's type printed per pass
# (`N` lines). NDW_STACK=ports: NetworkDynamics on the trait ports (TraitDifferentialEquations, and GraphMakie over
# MakieCompat in workload_plot.jl); else upstream's packages.
module NDW

const API = get(ENV, "NDW_API", "upstream")
const ON_PORTS = get(ENV, "NDW_STACK", "upstream") == "ports"
@static if ON_PORTS
    using NetworkDynamics, Graphs, TraitDifferentialEquations
    const GETU = TraitDifferentialEquations.getu
else
    using NetworkDynamics, Graphs, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
end
import SymbolicIndexingInterface as SII
using Printf
@static if !ON_PORTS
    const GETU = SII.getu
end
const STIFF = API == "ports" ? Rodas5 : Rodas5P

const OUT = joinpath(@__DIR__, "..", "out")
const PASS = Ref("first")
const SOLVE_KW = get(ENV, "NDW_TIGHT", "0") == "1" ? (; abstol = 1e-12, reltol = 1e-12) : (; abstol = 1e-8, reltol = 1e-6)   # NDW_TIGHT=1: the tie-break run (R5)
const TIMES = [0.5, 1.0, 1.5, 2.0, 3.0, 4.5, 6.0]
const SAVE_KW = API != "ports" ? (;) : get(ENV, "NDW_TSTOPS", "0") == "1" ? (; saveat = TIMES, tstops = TIMES) : (; saveat = TIMES)
# NDW_TSTOPS=1 (R5's supplement): the steps end at TIMES too, so the saved values are steps' ends, not interpolated
"The values of `sol(ts; idxs)`: a `DiffEqArray`'s upstream, a `Vector` on the ports."
vals(x) = x isa Vector ? x : x.u

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
    model === :swing_type && return usertype_models()    # the `usertype` pass (workload_types.jl, the ports only)
    vertex = model === :swing ?
        VertexModel(f = swing!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1]) :
        VertexModel(f = swing2!, g = 1, sym = [:δ, :ω], psym = [:P_ref, :I => 1, :γ => 0.1, :κ => 0.5])
    edge = EdgeModel(g = AntiSymmetric(line!), outsym = :P, psym = [:K => 6.0, :limit => 1.0])
    (; vertex, edge)
end
@static if ON_PORTS
    include(joinpath(@__DIR__, "workload_types.jl"))   # R6 (E-247): a user's own component types
end
digest_a(r) = digest("a", :vdim => dim(r.vertex), :vpdim => pdim(r.vertex), :edim => dim(r.edge), :epdim => pdim(r.edge))

# ---- b. the network -----------------------------------------------------------------------------
function step_b(r)
    g = watts_strogatz(20, 4, 0.2; seed = 42)
    Network(g, r.vertex, r.edge; dealias = true)
end
# the `graphtype` pass (the graph plan's G7, E-154): the same graph as a `Graphs.Test.GenericGraph`. A `Val`, so
# that the other passes' code does not infer the other graph type's network (that moved 5 s of compile into b)
step_b(r, ::Val{:simple}) = step_b(r)
step_b(r, ::Val{:generic}) = Network(Graphs.Test.generic_graph(watts_strogatz(20, 4, 0.2; seed = 42)), r.vertex, r.edge; dealias = true)
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
# the ports' variant (R5): the angles centred on their mean, `δc`: a fixed point of the swing equations is fixed only up to
# a common shift of the angles, which the nonlinear solver's path chooses
digest_c(r) = digest("c", :u => bits(uflat(r.s)), :p => bits(pflat(r.s)),
                     (API == "ports" ? (:δc => num(r.s.v[1:5, :δ] .- sum(r.s.v[:, :δ]) / length(r.s.v[:, :δ])),) : (:δ => num(r.s.v[1:5, :δ]),))...,
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
    sol = solve(fresh(), Tsit5(); SOLVE_KW..., SAVE_KW...)
    ttrips = copy(trips); empty!(trips)
    rsol = solve(fresh(), STIFF(); SOLVE_KW..., SAVE_KW...)
    (; prob, sol, rsol, ttrips, rtrips = copy(trips))
end
function digest_d(r)
    ω = vals(r.sol(TIMES; idxs = VIndex(2, :ω)))
    ωr = vals(r.rsol(TIMES; idxs = VIndex(2, :ω)))
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
    getP = GETU(sol, eidxs(nw, :, :P))
    (; ωsum = [sum(u) for u in vals(ωall)], P2 = vals(P2), P3 = s3.e[1:6, :P], K3 = s3.p.e[1:6, :K], Pend = getP(sol)[end][1:6])
end
digest_e(r) = digest("e", :ωsum => num(r.ωsum), :P2 => num(r.P2), :P3 => num(r.P3), :K3 => num(r.K3), :Pend => num(r.Pend))

# ---- the passes ---------------------------------------------------------------------------------
"Steps a–e for one model; `timed(name, f)` runs and times each step, the digests outside it."
function run_sim(timed, pass, model; γ = 0.1, graph = Val(:simple))
    PASS[] = pass
    a = timed("a", () -> step_a(model)); digest_a(a)
    nw = timed("b", () -> step_b(a, graph)); digest_b(nw)
    API == "ports" && println("N ", pass, " nwtype ", string(hash(typeof(nw)); base = 16), " ", nameof(typeof(nw)), "{", length(typeof(nw).parameters), " parameters}")
    c = timed("c", () -> step_c(nw; γ)); digest_c(c)
    d = timed("d", () -> step_d(nw, c.s)); digest_d(d)
    e = timed("e", () -> step_e(nw, d.sol)); digest_e(e)
    (; nw, d, model)
end
"Steps f and g (workload_plot.jl) on what `run_sim` returned."
function run_plot(timed, st)
    f = timed("f", () -> step_f(st.nw, st.d.sol, st.model)); digest_f(f)
    g = timed("g", () -> step_g(st.nw, st.d.prob, st.model)); digest_g(g)
    (st.nw, st.d.prob)
end
"Steps a–g for one model; `graph = Val(:generic)`: the network on a `Graphs.Test.GenericGraph` (step b)."
run_pass(timed, pass, model; γ = 0.1, graph = Val(:simple)) = run_plot(timed, run_sim(timed, pass, model; γ, graph))

"The control: the parameters changed on the problem of the first pass (`remake`), no new types."
function run_params(timed, nw, prob)
    PASS[] = "params"
    d = timed("d", () -> begin
        p = copy(prob.p); s = NWParameter(nw, p); s.v[:, :γ] .= 0.2
        prob2 = remake(prob; p = pflat(s))
        (; prob = prob2, sol = solve(prob2, Tsit5(); SOLVE_KW..., SAVE_KW...))
    end)
    digest("d", :retcode => d.sol.retcode, :ω2 => num(vals(d.sol(TIMES; idxs = VIndex(2, :ω)))))
    e = timed("e", () -> step_e(nw, d.sol)); digest_e(e)
    f = timed("f", () -> step_f(nw, d.sol, :params)); digest_f(f)
    g = timed("g", () -> step_g(nw, d.prob, :params)); digest_g(g)
    nothing
end

end # module
