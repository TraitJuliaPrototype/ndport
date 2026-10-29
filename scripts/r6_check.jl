# R6 (E-247): part 3b's checks beside the workload's `usertype` pass, in setting PT (env_r5):
# the records of `Swing`/`Line` (workload_types.jl) against the function models' (swing!, line! under AntiSymmetric);
# the record's adaptors called at upstream's convention (compfg), bitwise; the doctor; the right-hand side in the
# sequential, threaded and Polyester styles, bitwise, and the network's type; linearize_component and
# initialize_component on a Swing vertex; the refusals. Prints `R6 <check> <result>` lines.
#     scripts/r5_run.sh <name> scripts/r6_check.jl     (NDW_LOGDIR=logs/r6 NDW_JLNAME=ndr6)
ENV["NDW_API"] = "ports"; ENV["NDW_STACK"] = "ports"
using Graphs, NetworkDynamics, TraitDifferentialEquations, SymbolicIndexingInterface, Random
include(joinpath(@__DIR__, "workload_steps.jl"))
const ND = NetworkDynamics
r6(name, x) = (println("R6 ", name, " ", x); flush(stdout))
bits(x) = string(hash(reinterpret(UInt64, collect(Float64, x))); base = 16)
function check(name, f)
    try
        r6(name, f())
    catch err
        r6(name, "ERROR " * sprint(showerror, err)[1:min(end, 300)])
    end
end

fm = NDW.step_a(:swing); um = NDW.step_a(:swing_type)
for (k, a, b) in ((:vertex, fm.vertex, um.vertex), (:edge, fm.edge, um.edge))
    for fld in (:sym, :psym, :outsym, :insym, :obssym, :ff, :mass_matrix, :extin, :symmetadata, :_outsym_flat, :_obssym_all)
        getfield(a, fld) == getfield(b, fld) || r6("record-$k-$fld", "DIFFERS $(repr(getfield(a, fld))) $(repr(getfield(b, fld)))")
    end
    r6("record-$k", "f=$(typeof(um[k].f)) g=$(typeof(um[k].g)) name=$(um[k].name) ($(a.name))")
end

# the adaptors at upstream's convention, against the function models', on the same random inputs
function compfg_bits(c, rng)
    du = rand(rng, dim(c)); u = rand(rng, dim(c)); p = rand(rng, pdim(c))
    outs = Tuple(rand(rng, l) for l in values(outdim(c)))
    ins = c isa VertexModel ? (rand(rng, 1),) : (rand(rng, 1), rand(rng, 1))
    ND.compfg(c)(outs, du, u, ins, p, 0.3)
    bits(vcat(du, outs...))
end
for k in (:vertex, :edge)
    check("compfg-$k", () -> (a = compfg_bits(fm[k], MersenneTwister(1)); b = compfg_bits(um[k], MersenneTwister(1)); a == b ? "equal $a" : "DIFFERS $a $b"))
    check("doctor-$k", () -> (ND.chk_component(um[k]); "ran"))
end

# the right-hand side in each execution style: bitwise, and the network's type
g = watts_strogatz(20, 4, 0.2; seed = 42)
for ex in (SequentialExecution{true}(), ThreadedExecution{true}(), PolyesterExecution{true}())
    check("rhs-$(nameof(typeof(ex)))", () -> begin
        nf = Network(g, fm.vertex, fm.edge; execution = ex, dealias = true)
        nu = Network(g, um.vertex, um.edge; execution = ex, dealias = true)
        rng = MersenneTwister(2); u = rand(rng, dim(nf)); p = rand(rng, pdim(nf))
        duf = zeros(dim(nf)); duu = zeros(dim(nu))
        nf(duf, u, p, 0.0); nu(duu, u, p, 0.0)
        "$(bits(duf) == bits(duu) ? "equal" : "DIFFERS") $(bits(duf)) sametype=$(typeof(nf) == typeof(nu))"
    end)
end

# component-level callers through the adaptors, on the vertex with an input named (linearization and
# initialization need one): the same calls on the function model and on `Swing`
for model in (:swing, :swing_type)
    v = VertexModel(NDW.step_a(model).vertex; insym = [:Pin])
    check("linearize-$model", () -> begin
        sys = linearize_component(v, [0.3, 0.05], [1.0, 1.0, 0.1], [-0.8], [0.3], 0.0)
        "A=$(bits(sys.A)) B=$(bits(sys.B)) C=$(bits(sys.C)) D=$(bits(sys.D))"
    end)
    check("initialize-$model", () -> begin
        w = copy(v)
        set_default!(w, :P_ref, 1.0); set_default!(w, :Pin, -1.0); set_default!(w, :δ, 0.3); set_guess!(w, :ω, 0.1)
        st = initialize_component(w; verbose = false)
        "δ=$(st[:δ]) ω=$(st[:ω])"
    end)
end

# the refusals
check("refuse-kind", () -> (VertexModel(dynamics = NDW.Line(), sym = [:x], psym = [:K, :limit]); "NOT REFUSED"))
check("refuse-pdim", () -> (VertexModel(dynamics = NDW.Swing(), sym = [:δ, :ω], psym = [:P], allow_output_sym_clash = true); "NOT REFUSED"))
check("refuse-f", () -> (VertexModel(dynamics = NDW.Swing(), f = NDW.swing!, sym = [:δ, :ω], psym = [:P, :I, :γ]); "NOT REFUSED"))
check("refuse-plain", () -> (VertexModel(dynamics = 1.0, sym = [:x]); "NOT REFUSED"))
# a record rebuilt with new dynamics, and one rebuilt from a user's record
check("reconstruct", () -> begin
    v1 = VertexModel(fm.vertex; dynamics = NDW.Swing())
    v2 = VertexModel(um.vertex; psym = [:P_ref, :I => 2, :γ => 0.1])
    "from-function g=$(typeof(v1.g)) from-user g=$(typeof(v2.g)) I=$(get_default(v2, :I))"
end)
r6("done", "")
