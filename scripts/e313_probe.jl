# E-313: NetworkDynamics' steady-state solve (step d) after the `again` pass, timed and profiled.
#   NDW_API=ports NDW_STACK=ports NDW_PASSES=again julia --project=env_unified_r5 --threads=1 scripts/e313_probe.jl
include(joinpath(@__DIR__, "workload.jl"))
c = NDW.step_c(nw; γ = 0.1)
for i in 1:3
    t = @elapsed NDW.step_d(nw, c.s)
    println("P step_d ", round(t * 1000; digits = 1), " ms")
end
println("P vertex batch ", typeof(nw.vertexbatches[1]))
println("P edge batch ", typeof(nw.layer.edgebatches[1]))
println("P vertex batch fields ", [(n, typeof(getfield(nw.vertexbatches[1], n))) for n in fieldnames(typeof(nw.vertexbatches[1]))])
let r = try
        TW = only(m for m in values(Base.loaded_modules) if nameof(m) === :TraitWorld)
        TW.detect_unused_casts(NetworkDynamics)
    catch err
        sprint(showerror, err)
    end
    println("P unused casts in NetworkDynamics: ", r)
end
using Profile
Profile.init(n = 10^7, delay = 0.0005)
@profile for i in 1:3; NDW.step_d(nw, c.s); end
Profile.print(IOContext(stdout, :displaysize => (200, 230)); format = :flat, sortedby = :count, mincount = 60, C = true)
