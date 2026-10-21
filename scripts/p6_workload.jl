# P6 (E-155): the workload (workload.jl, unchanged) for setting I, then strict mode's state as the session saw it
# (`STRICT on|off`, TraitWorld.STRICT[]), since a run whose strict mode was not on is void (the plan §3.1, check S).
include(joinpath(@__DIR__, "workload.jl"))
println("STRICT ", TraitWorld.STRICT[] ? "on" : "off")
