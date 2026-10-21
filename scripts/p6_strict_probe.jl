# P6 check S+ (E-155, the plan §3.1): strict mode's positive control at S2. After the workload's steps a–d have run,
# find a fact held only by SciMLBase's code compiled by facts: an edge from a facts CodeInstance of a SciMLBase method
# to a concrete call of a neutral method outside SciMLBase, held by no other package's facts code. Main then defines a
# more specific method at exactly that signature, which `invoke`s the old one (correct in value): a pirate (Main owns
# neither the function nor a type) that wins at SciMLBase's fact. Strict mode on: refused, and the refusal's caller
# (`_trait_root`) is SciMLBase's code. Prints `SP fact …`, `SP defined=<accepted|error type>`, `SP root=<module.name>`,
# `SP pass=<true|false>`.  Run by the harness: NDW_STRICT=1 NDW_SCRIPT=scripts/p6_strict_probe.jl run_workload.sh <tag> I
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
include(joinpath(@__DIR__, "workload_steps.jl"))
println("STRICT ", TraitWorld.STRICT[] ? "on" : "off")
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw); d = NDW.step_d(nw, c.s)
const FO = Base.Compiler.FACTS_OWNER
const SB = Base.root_module(Base.PkgId(Base.UUID("0bca4576-84f4-4d90-8ffe-ffa030f20462"), "SciMLBase"))
facts(m) = m isa Method && ccall(:jl_method_is_facts, Cint, (Any,), m) != 0
# callee MethodInstance => the set of root modules whose facts code holds an edge to it
holders = IdDict{Core.MethodInstance,Set{Module}}()
Base.visit(Core.methodtable) do m
    m isa Method || return
    r = Base.moduleroot(m.module)
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            if ci.owner === FO && ci.max_world == typemax(UInt) && isdefined(ci, :edges)
                for e in ci.edges
                    e isa Core.CodeInstance && (e = e.def isa Core.MethodInstance ? e.def : e.def.def)
                    e isa Core.MethodInstance || continue
                    push!(get!(Set{Module}, holders, e), r)
                end
            end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
function candidate()
    best = nothing
    for (mi, rs) in holders
        rs == Set([SB]) || continue
        m = mi.def; m isa Method || continue
        facts(m) && continue                                   # a neutral method's call (its code plain or by facts)
        Base.moduleroot(m.module) === SB && continue
        isconcretetype(mi.specTypes) || continue
        ps = mi.specTypes.parameters
        ft = ps[1]; isdefined(ft, :instance) || continue
        any(p -> p <: Type || p <: Core.Builtin, ps[2:end]) && continue
        2 <= length(ps) <= 4 || continue
        string(m.name)[1] == '#' && continue                  # no closures or keyword bodies
        m.name in (:methods, :which, :invoke, :getfield, :setfield!) && continue
        (best === nothing || length(string(mi.specTypes)) < length(string(best.specTypes))) && (best = mi)
    end
    return best                                               # the shortest signature: the simplest pirate
end
println("SP edges: ", length(holders), " callees; held by SciMLBase alone: ", count(rs -> rs == Set([SB]), values(holders)))
mi = candidate()
if mi === nothing
    println("SP no fact held only by SciMLBase found"); println("SP pass=false"); exit(0)
end
ps = collect(mi.specTypes.parameters); f = ps[1].instance; args = ps[2:end]
println("SP fact ", mi.specTypes, " (method ", mi.def.module, " ", mi.def.file, ":", mi.def.line, ")")
xs = [Symbol("x", i) for i in eachindex(args)]
ex = :((::$(typeof(f)))($([:($x::$T) for (x, T) in zip(xs, args)]...)) = invoke($f, $(mi.def.sig), $(xs...)))
defined = try
    Core.eval(Main, ex); "accepted"
catch e
    global err = e
    println("SP error: ", first(sprint(showerror, e), 700)); string(typeof(e))
end
root = if @isdefined(err) && err isa TraitWorld.PirateError
    r = TraitWorld._trait_root(err.caller)
    r === nothing ? "none" : (r.def isa Method ? "$(r.def.module).$(r.def.name)" : string(r))
else
    "none"
end
println("SP defined=", defined, " root=", root)
println("SP pass=", defined == "TraitWorld.PirateError" && startswith(root, "SciMLBase"))
