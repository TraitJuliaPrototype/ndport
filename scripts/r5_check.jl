# W-32, open issue 118 (E-245): r3_workload.jl with the workload's `SII.getu(sol, …)` read by TDE's `getu` (the trait
# protocol: the network an `IndexProvider{I}` of its own indices), checked exactly against NetworkDynamics' own
# reading over `NWState` at the saved times; a callback's view and the integrator read by `getu` too.
#     scripts/r5_run.sh <name> scripts/r5_check.jl
# The R3 header: W-32 step R3 (E-242): r2_workload.jl with TDE's R3 items (marked R3): `find_fixpoint` by TraitNonlinearSolve (the
# relaxation stand-in only where it fails, and compared with it), TDE's `remake`, the solution's `idxs` forms by
# NetworkDynamics' own indexing (TDE's solution call dispatching on the index type), dense output (open issue 117)
# checked against the saveat values. `SII.getu(sol, …)` is still tried (open issue 118).
# The R2 header: W-32 step R2 (E-239): r1_workload.jl with the calls in the ports' form where TDE's R2 items give them (marked R2):
# the problem keeps the network's callbacks (`ODEProblem(nw, s0, tspan)`), callbacks reused across solves, Rodas5
# with continuous callbacks, the network back from a solution (`NWState(sol, t)`, `extract_nw(sol)`), saved
# parameters, `init`/`step!` and `NWState(integ)`. The rest as in R1.
# The R1 header: W-32 step R1 (E-236): the census of the ports' gaps by running. Tier S's steps a–e and g's integrator part
# in the ports' form (the reactivation plan's choices C2, C3, C7: Rodas5, a new problem instead of `remake`,
# values at TIMES by `saveat`, NetworkDynamics' own indexing over `NWState`), on setting PT (env_ports).
# Each upstream call is tried first; where it fails, the failure is printed and, where one is marked, a
# stand-in carries the step on so that the next failure shows. Not a measurement; the digests are not
# compared (the stand-ins change results).
#     julia --project=env_ports scripts/r1_workload.jl        (from ndport/; scripts/r1_run.sh)
# Prints `R1 <pass> <step> <what> ok` or `R1 <pass> <step> <what> FAIL <exception>: <message> @ <frames>`,
# and `R1 <pass> <step> <what> STANDIN <what stands in>`.
using Graphs, NetworkDynamics, TraitDifferentialEquations
import SymbolicIndexingInterface as SII
using Printf

module R1W
using Graphs, NetworkDynamics, TraitDifferentialEquations
import SymbolicIndexingInterface as SII
import NetworkDynamics: ODECore

const PASS = Ref("first")
const SOLVE_KW = (; abstol = 1e-8, reltol = 1e-6)
const TIMES = [0.5, 1.0, 1.5, 2.0, 3.0, 4.5, 6.0]
const NFAIL = Ref(0)

function frames(bt)
    out = String[]
    for fr in stacktrace(bt)
        f = string(fr.file)
        (occursin("r1_workload", f) || occursin("NetworkDynamics-ports", f) || occursin("TraitDifferentialEquations", f) ||
         occursin("TraitWorld", f) || occursin("r1_stubs", f)) || continue
        push!(out, string(fr.func, "@", basename(f), ":", fr.line))
        length(out) >= 4 && break
    end
    join(out, " < ")
end
"Try `f()`; print ok or the failure; return `(true, value)` or `(false, nothing)`."
function attempt(step, what, f)
    try
        v = Base.invokelatest(f)
        println("R1 ", PASS[], " ", step, " ", what, " ok"); flush(stdout)
        return true, v
    catch err
        NFAIL[] += 1
        msg = first(split(sprint(showerror, err), '\n'))
        println("R1 ", PASS[], " ", step, " ", what, " FAIL ", nameof(typeof(err)), ": ", first(msg, 300), " @ ", frames(catch_backtrace()))
        flush(stdout)
        return false, nothing
    end
end
standin(step, what, how) = (println("R1 ", PASS[], " ", step, " ", what, " STANDIN ", how); flush(stdout))

# ---- a. components (as workload_steps.jl) --------------------------------------------------------
function swing!(dv, v, esum, p, t)
    P, I, γ = p
    dv[1] = v[2]
    dv[2] = (P - γ * v[2] + esum[1]) / I
    nothing
end
function swing2!(dv, v, esum, p, t)
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

# ---- b. the network ----------------------------------------------------------------------------
step_b(r, ::Val{:simple}) = Network(watts_strogatz(20, 4, 0.2; seed = 42), r.vertex, r.edge; dealias = true)
step_b(r, ::Val{:generic}) = Network(Graphs.Test.generic_graph(watts_strogatz(20, 4, 0.2; seed = 42)), r.vertex, r.edge; dealias = true)

# ---- c. the fixed point and its linear stability -------------------------------------------------
"Stand-in for `find_fixpoint` (S8): relax the network from zero by Rodas5 over (0, 400) and take the end state."
function relax(nw)
    s0 = NWState(nw; ufill = 0.0)
    prob = ODEProblem(nw, s0, (0.0, 400.0))
    sol = solve(prob, Rodas5(); abstol = 1e-10, reltol = 1e-10)
    NWState(nw, sol.u[end], pflat(s0))
end
function step_c(nw; γ = 0.1)
    for i in 1:nv(get_graph(nw))
        set_default!(nw, VIndex(i, :P_ref), isodd(i) ? 1.0 : -1.0)
        set_default!(nw, VIndex(i, :γ), γ)
    end
    ok, u0 = attempt("c", "find_fixpoint(nw)", () -> find_fixpoint(nw))
    if !ok
        standin("c", "find_fixpoint(nw)", "relax(nw): Rodas5 over (0, 400) from zero")
        ok, u0 = attempt("c", "relax(nw)", () -> relax(nw))
        ok || return nothing
    end
    # R3: the fixed point by Newton against the relaxation's end state (the census' stand-in, R1-b)
    # (the angles are fixed only up to a common shift: compared by the line flows and the frequencies)
    attempt("c", "find_fixpoint(nw) ≈ relax(nw)", () -> (r = relax(nw);
        d = max(maximum(abs, u0.e[:, :P] .- r.e[:, :P]), maximum(abs, u0.v[:, :ω] .- r.v[:, :ω]));
        println("R1 ", PASS[], " c info |find_fixpoint - relax| (flows, ω) = ", d); d < 1e-6 || error("differs by $d"); true))
    set_defaults!(nw, u0)
    s = NWState(nw)
    _, λ = attempt("c", "jacobian_eigenvals(s)", () -> jacobian_eigenvals(s))
    _, fix = attempt("c", "isfixpoint(s)", () -> isfixpoint(s))
    _, _ = attempt("c", "s.e[:, :P] (observed)", () -> maximum(abs, s.e[:, :P]))
    (; s, fix, λmax = λ === nothing ? NaN : maximum(real, λ))
end

# ---- d. solve, with a cascade of line trips ------------------------------------------------------
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
    first_trip = argmax(abs.(s.e[:, :P]))
    add_callback!(nw[EIndex(first_trip)], PresetTimeComponentCallback(1.0, affect))
    okp, prob = attempt("d", "ODEProblem(nw, NWState(nw), tspan)", () -> ODEProblem(nw, NWState(nw), (0.0, 6.0)))
    okp || return nothing
    # R3: TDE's `remake`, as upstream's workload uses it (the callbacks write K = 0 into the parameters)
    okr0, _ = attempt("d", "remake(prob; p)", () -> remake(prob; p = copy(prob.p)))
    fresh() = okr0 ? remake(prob; p = copy(prob.p)) : ODEProblem(nw, NWState(nw), (0.0, 6.0))
    # R2: the problem keeps the network's callbacks (TDE's `ODEProblem(…; callback)`), reused across solves (`initialize`)
    attempt("d", "get_callbacks(nw)", () -> get_callbacks(nw))
    s0 = NWState(nw)
    attempt("d", "ODEProblem(ODEFunction(nw; sys = nw), …)", () -> ODEProblem(ODEFunction(nw; sys = nw), uflat(s0), (0.0, 6.0), copy(pflat(s0))))
    attempt("d", "ODEProblem(ODEFunction(nw; mass_matrix = nw.mass_matrix), …)", () -> ODEProblem(ODEFunction(nw; mass_matrix = nw.mass_matrix), uflat(s0), (0.0, 6.0), copy(pflat(s0))))
    empty!(trips)
    # 118: a callback's view of the integrator reads the network's indices by getu (a TDE callback beside the network's)
    attempt("d", "getu(view, EIndex(2, :P))(view) in a callback", () -> begin
        seen = Float64[]
        look = DiscreteCallback((u, t, i) -> isempty(seen) && t > 0.5,
            i -> (push!(seen, getu(i, EIndex(2, :P))(i), NWState(extract_nw(i), copy(i.u), copy(i.p), i.t)[EIndex(2, :P)]); nothing))
        solve(ODEProblem(nw, NWState(nw), (0.0, 1.0)), Tsit5(); callback = look, SOLVE_KW...)
        empty!(trips); length(seen) == 2 && seen[1] == seen[2] || error("seen $seen"); seen[1]
    end)
    oks, sol = attempt("d", "solve(prob, Tsit5(); saveat)", () -> solve(fresh(), Tsit5(); saveat = TIMES, SOLVE_KW...))
    ttrips = copy(trips); empty!(trips)
    okr, rsol = attempt("d", "solve(prob, Rodas5(); saveat)", () -> solve(fresh(), Rodas5(); saveat = TIMES, SOLVE_KW...))
    rtrips = copy(trips); empty!(trips)
    oks || return nothing
    println("R1 ", PASS[], " d info retcode=", sol.retcode, " trips=", join(first.(ttrips), ","), " ttrips=", join(round.(last.(ttrips); digits = 4), ","),
            okr ? string(" rretcode=", rsol.retcode, " rtrips=", join(first.(rtrips), ","), " rttrips=", join(round.(last.(rtrips); digits = 4), ",")) : "")
    # R2: the same problem solved twice gives the same trips (the preset time's tstop added at each solve's init)
    attempt("d", "the problem solved again: the same trips", () -> (solve(prob, Tsit5(); saveat = TIMES, SOLVE_KW...); t1 = copy(trips); empty!(trips);
        solve(ODEProblem(nw, NWState(nw), (0.0, 6.0)), Tsit5(); saveat = TIMES, SOLVE_KW...); t1 == trips || error("trips differ"); empty!(trips); true))
    attempt("d", "sol(TIMES; idxs = VIndex(2, :ω))", () -> sol(TIMES; idxs = VIndex(2, :ω)))
    # R3: dense output: the solve without saveat, read at TIMES by Tsit5's interpolant, against the saveat values (a new
    # problem: the solve of `prob` above wrote the trips into `prob.p`, which `fresh()` copies)
    attempt("d", "dense sol(TIMES) = the saveat values", () -> (empty!(trips); sd = solve(ODEProblem(nw, NWState(nw), (0.0, 6.0)), Tsit5(); SOLVE_KW...); dtrips = copy(trips); empty!(trips);
        e = maximum(maximum(abs, sd(t) .- sol.u[k]) for (k, t) in enumerate(sol.t));
        e < 1e-12 || println("R1 ", PASS[], " d info dense per time ", [maximum(abs, sd(t) .- sol.u[k]) for (k, t) in enumerate(sol.t)],
                             " trips ", join(first.(dtrips), ","), " at ", join(round.(last.(dtrips); digits = 4), ","), " t ", sol.t);
        println("R1 ", PASS[], " d info dense-saveat max = ", e); e < 1e-12 || error("differs by $e"); true))
    (; prob, sol, rsol)
end

# ---- e. access by symbolic index -----------------------------------------------------------------
function step_e(nw, sol)
    attempt("e", "sol(TIMES; idxs = vidxs(nw, :, :ω))", () -> sol(TIMES; idxs = vidxs(nw, :, :ω)))
    attempt("e", "sol(TIMES; idxs = EIndex(2, :P))", () -> sol(TIMES; idxs = EIndex(2, :P)))
    attempt("e", "NWState(sol, 3.0)", () -> NWState(sol, 3.0))
    attempt("e", "extract_nw(sol)", () -> NetworkDynamics.extract_nw(sol))
    attempt("e", "SII.getu(sol, eidxs(nw, :, :P))", () -> SII.getu(sol, eidxs(nw, :, :P))(sol))
    # 118: TDE's getu by the network's own indices, against NetworkDynamics' own reading over NWState
    attempt("e", "getu(sol, eidxs(nw, :, :P))(sol) = NWState(sol, t).e[:, :P]", () -> begin
        v = getu(sol, eidxs(nw, :, :P))(sol)
        w = [NWState(sol, t).e[:, :P] for t in sol.t]
        v == w || error("differ: max ", maximum(maximum(abs, a .- b) for (a, b) in zip(v, w))); length(v)
    end)
    attempt("e", "getu(sol, VIndex(2, :ω)), EIndex(2, :K), [EIndex(1, :P), VIndex(1, :δ)]", () -> begin
        a = getu(sol, VIndex(2, :ω))(sol) == [NWState(sol, t)[VIndex(2, :ω)] for t in sol.t]
        b = getu(sol, EIndex(2, :K))(sol) == [NWState(sol, t).p.e[2, :K] for t in sol.t]
        c = getu(sol, [EIndex(1, :P), VIndex(1, :δ)])(sol) == [NWState(sol, t)[[EIndex(1, :P), VIndex(1, :δ)]] for t in sol.t]
        (a && b && c) || error("differ: $a $b $c"); true
    end)
    attempt("e", "getu(sol, VIndex(1, :nosuch)) refused", () -> (try getu(sol, VIndex(1, :nosuch)); error("accepted") catch e; e isa ArgumentError || rethrow(); true end))
    # R3: the idxs forms against NetworkDynamics' own indexing over NWState
    attempt("e", "sol(TIMES; idxs) = NWState(sol, t)[idxs]", () -> begin
        a = sol(TIMES; idxs = VIndex(2, :ω)) == [NWState(sol, t)[VIndex(2, :ω)] for t in TIMES]
        b = sol(TIMES; idxs = EIndex(2, :P)) == [NWState(sol, t)[EIndex(2, :P)] for t in TIMES]
        c = sol(3.0; idxs = vidxs(nw, :, :ω)) == NWState(sol, 3.0).v[:, :ω]
        (a && b && c) || error("differ: $a $b $c"); true
    end)
    attempt("e", "NWState(sol, t) over the saved times", () -> begin
        ss = [NWState(sol, t) for t in sol.t]
        (; ωsum = [sum(s.v[:, :ω]) for s in ss], P2 = [s.e[2, :P] for s in ss], K3 = ss[findfirst(==(3.0), sol.t)].p.e[1:6, :K])
    end)
    # R2: the line constants at t = 3 from the parameters the callbacks saved: tripped lines at K = 0
    attempt("e", "K at t = 3 from the saved parameters", () -> begin
        K3 = NWState(sol, 3.0).p.e[:, :K]
        any(iszero, K3) || error("no tripped line at t = 3: the parameters were not saved")
        count(iszero, K3)
    end)
end

# ---- g's integrator part (the plotting itself: E-237) --------------------------------------------
function step_g(nw, prob)
    # R2: TDE's `init`, `step!` and the integrator in user code
    ok, integ = attempt("g", "init(prob, Tsit5())", () -> init(prob, Tsit5(); SOLVE_KW...))
    ok || return nothing
    attempt("g", "step!(integ, 0.6, true)", () -> (step!(integ, 0.6, true); integ.t == 0.6 || error("t = $(integ.t)")))
    attempt("g", "NWState(integ)", () -> NWState(integ))
    attempt("g", "getu(integ, EIndex(2, :P))(integ) = NWState(integ)[EIndex(2, :P)]", () -> (a = getu(integ, EIndex(2, :P))(integ);
        a == NWState(integ)[EIndex(2, :P)] || error("differ"); a))
    attempt("g", "step!(integ, 0.6, true) again; NWState(integ) at 1.2", () -> (step!(integ, 0.6, true); NWState(integ).t))
end

function run_pass(pass, model; γ = 0.1, graph = Val(:simple))
    PASS[] = pass
    oka, a = attempt("a", "VertexModel/EdgeModel", () -> step_a(model)); oka || return nothing
    okb, nw = attempt("b", "Network(g, v, e)", () -> step_b(a, graph)); okb || return nothing
    c = step_c(nw; γ); c === nothing && return nothing
    d = step_d(nw, c.s); d === nothing && return nothing
    step_e(nw, d.sol)
    step_g(nw, d.prob)
    (; nw, d)
end
function run_params(nw, prob)
    PASS[] = "params"
    attempt("d", "NWParameter(nw, p); new problem; solve", () -> begin
        s = NWParameter(nw, copy(prob.p)); s.v[:, :γ] .= 0.2
        prob2 = ODEProblem(nw, NWState(nw, copy(prob.u0), s), (0.0, 6.0))
        solve(prob2, Tsit5(); saveat = TIMES, SOLVE_KW...)
    end)
end
end # module R1W

println("# r5_check ", R1W.PASS[], " julia ", VERSION)
st = R1W.run_pass("first", :swing)
R1W.run_pass("again", :swing)
st === nothing || R1W.run_params(st.nw, st.d.prob)
R1W.run_pass("changed", :swing2)
R1W.run_pass("graphtype", :swing; graph = Val(:generic))
println("R1 usertype - - n/a: the pass is part 3b (R6), not yet in the workload")
println("R1 failures ", R1W.NFAIL[])
