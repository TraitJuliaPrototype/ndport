# P6 diagnostic (S2's steady-state regression): plain code reading fields through SciMLBase's `getproperty`
# overloads on abstract types (`DEIntegrator`, `AbstractSolution`, `AbstractSciMLProblem`, `AbstractSciMLFunction`).
# With SciMLBase a trait module those are facts methods; plain callers infer them in their own inference, without
# constant propagation across the modes (facts §6.3), so `x.field` gives the union of all fields' types.
# Prints the inferred result of plain lambdas `x -> x.<field>` and `x -> getfield(x, :<field>)` for the workload's
# integrator, solution, problem and function, whether `getproperty` is a facts method, and the typed code of DiffEqBase's
# `get_condition` (the steady state's hottest plain caller in the profile).
using TraitWorld, OrdinaryDiffEqTsit5, DiffEqBase, SciMLBase
f!(du, u, p, t) = (du .= -u; nothing)
prob = ODEProblem(f!, [1.0, 2.0], (0.0, 1.0))
integ = init(prob, Tsit5()); sol = solve(prob, Tsit5())
facts(m) = ccall(:jl_method_is_facts, Cint, (Any,), m) != 0
for (x, fields) in ((integ, (:sol, :u, :t, :callback_cache, :opts, :cache)), (sol, (:u, :t, :stats, :prob, :interp)),
                    (prob, (:u0, :p, :f, :tspan)), (prob.f, (:f, :mass_matrix)))
    m = which(getproperty, (typeof(x), Symbol))
    println("TYPE ", nameof(typeof(x)), "  getproperty: ", m.module, " ", basename(string(m.file)), ":", m.line, " facts=", facts(m))
    for fl in fields
        rp = only(Base.return_types(y -> getproperty(y, fl === :sol ? :sol : fl), (typeof(x),)))
        rc = only(Base.return_types(eval(:(y -> y.$fl)), (typeof(x),)))
        rf = only(Base.return_types(eval(:(y -> getfield(y, $(QuoteNode(fl))))), (typeof(x),)))
        println("  .", fl, ": x.$fl -> ", rc, " | getfield -> ", rf, rc == rf ? "" : "   WIDER")
    end
end
