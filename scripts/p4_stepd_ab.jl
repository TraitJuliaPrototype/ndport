# Criterion 4's failing step d, attributed (E-152): in one session, step d's steady state on the network
# built with the erased batches (SequentialExecution: the barrier per batch) and with typed batches
# (PolyesterExecution{true}, which keeps upstream's batches; one thread runs Polyester's serial path).
# Also the right-hand-side calls step d makes. Diagnostic, not a measurement round.
#     julia --project=env_p4 scripts/p4_stepd_ab.jl
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
include(joinpath(@__DIR__, "workload_steps.jl"))
using .NDW
function build(ex)
    a = NDW.step_a(:swing)
    Network(watts_strogatz(20, 4, 0.2; seed = 42), a.vertex, a.edge; dealias = true, execution = ex)
end
for ex in (SequentialExecution{true}(), PolyesterExecution{true}(), SequentialExecution{true}(), PolyesterExecution{true}())
    nw = build(ex)
    c = NDW.step_c(nw)
    NDW.step_d(nw, c.s)                                   # compile
    ts = [(t0 = time_ns(); NDW.step_d(nw, c.s); (time_ns() - t0) / 1e6) for _ in 1:3]
    println("stepd ", nameof(typeof(ex)), " batches=", typeof(nw.vertexbatches) <: Vector ? "erased" : "typed",
            " ms=", round.(ts; digits = 1))
end
