# P6 (E-155) S6: the fold check of the plan's §8, risk 2, and the callback path of risk 3. Included by p6_census.jl
# (NDW_FOLD=1) after the workload's passes, with `nw`, `c`, `d` in scope.
# - Tsit5's `perform_step!` for the workload's cache type, as reflection shows the code that runs (facts inference for a
#   facts method, facts §7.2): does it still construct `Tsit5ConstantCacheActual` (the per-step tableau, `@fold`, that is
#   `@assume_effects :foldable`), or are the coefficients constants? Prints `FOLD <method> calls=<n> constructs=<k>`.
# - The workload's continuous callbacks: their container type and element types (VectorContinuousCallback's path
#   types the condition with `Nothing`, ContinuousCallback's with `promote_op`).
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
const ODECore = OrdinaryDiffEqTsit5.OrdinaryDiffEqCore
let prob = d.prob
    integ = Base.invokelatest(OrdinaryDiffEqTsit5.init, remake(prob; p = copy(prob.p)), OrdinaryDiffEqTsit5.Tsit5(); NDW.SOLVE_KW...)
    C = typeof(integ.cache)
    println("FOLD cache ", nameof(C), " facts(perform_step!)=", ccall(:jl_method_is_facts, Cint, (Any,), which(ODECore.perform_step!, (typeof(integ), C, Bool))) != 0)
    for (name, f, args) in (("perform_step!", ODECore.perform_step!, (typeof(integ), C, Bool)),
                            ("_ode_addsteps!", ODECore._ode_addsteps!, (typeof(integ.k), typeof(integ.t), typeof(integ.uprev), typeof(integ.u), typeof(integ.dt), typeof(integ.f), typeof(integ.p), C, Bool, Bool, Bool)))
        ci, rt = only(Base.code_typed(f, args; optimize = true))
        calls = 0; constructs = 0
        for st in ci.code
            st isa Expr || continue
            (st.head === :call || st.head === :invoke) || continue
            calls += 1
            occursin("Tsit5ConstantCacheActual", sprint(show, st)) && (constructs += 1)
        end
        println("FOLD ", name, " statements=", length(ci.code), " calls=", calls, " constructs_tableau=", constructs, " rt=", rt)
    end
    cbs = integ.opts.callback
    println("CALLBACKS continuous ", typeof(cbs.continuous_callbacks), " | discrete ", typeof(cbs.discrete_callbacks))
end
