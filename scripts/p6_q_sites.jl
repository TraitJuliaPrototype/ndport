# P6 diagnostic for Q at S2: SciMLBase's quick tests that fail only on the P6 trees are inference tests
# (`Base.return_types`, `@inferred`), which reflect facts inference for facts methods (facts §7.2). Where are the
# run-time sites that widen those results? TraitWorld's `fully_typed` on the two calls, from the tests' own setups
# (SciMLBase test/interpolation_tests.jl:150–158, test/solution_interface.jl:355–396).
using TraitWorld, SciMLBase, RecursiveArrayTools
t = collect(range(0, 10, length = 6)); u = [[sin(x), cos(x)] for x in t]; du = [[cos(x), -sin(x)] for x in t]
basic_dense = SciMLBase.BasicInterpolation(t, u, du, true)
for (name, f, args) in (("basic_dense(tvals)", basic_dense, (Vector{Float64}, Nothing, Type{Val{0}}, Nothing, Symbol)),)
    println("RT ", name, " => ", Base.return_types(f, args))
    r = TraitWorld.fully_typed(f, args)
    show(stdout, MIME"text/plain"(), r); println()
    for h in r.sites
        println("SITE ", h.kind, " ", h.line, " :: ", h.callee, " ", h.argtypes, " in ", h.caller)
    end
end
f = (u, p, t) -> -u
ode = ODEProblem(f, [1.0, 2.0], (0.0, 1.0))
odesol = SciMLBase.build_solution(ode, :NoAlgorithm, collect(0.0:0.1:1.0), [[exp(-t), 2exp(-t)] for t in 0.0:0.1:1.0])
uu = [1.0, 2.0]; resid = [0.0, 0.0]
nlsol = SciMLBase.NonlinearSolution{Float64, 1, typeof(uu), typeof(resid), Nothing, Nothing, Any, Nothing, Nothing, Nothing}(
    uu, resid, nothing, nothing, SciMLBase.ReturnCode.Success, [0.1, 0.2], nothing, nothing, nothing, nothing)
args = (typeof(odesol), typeof(nlsol), typeof(SciMLBase.ReturnCode.Success), typeof(resid))
println("RT solution_new_original_retcode => ", Base.return_types(SciMLBase.solution_new_original_retcode, args))
r = TraitWorld.fully_typed(SciMLBase.solution_new_original_retcode, args)
show(stdout, MIME"text/plain"(), r); println()
for h in r.sites
    println("SITE ", h.kind, " ", h.line, " :: ", h.callee, " ", h.argtypes, " in ", h.caller)
end
# the test's plain caller, which reads `n.resid` through SciMLBase's `getproperty(::AbstractSolution, ::Symbol)` (P6-1)
bvde_like(o, n::SciMLBase.NonlinearSolution) = SciMLBase.solution_new_original_retcode(o, n, SciMLBase.ReturnCode.Success, n.resid)
println("RT bvde_like => ", Base.return_types(bvde_like, (typeof(odesol), typeof(nlsol))))
println("RT n.resid => ", Base.return_types(n -> n.resid, (typeof(nlsol),)), " getfield => ", Base.return_types(n -> getfield(n, :resid), (typeof(nlsol),)))
