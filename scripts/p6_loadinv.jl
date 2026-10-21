# P6 check J (E-155, the plan §3.1): what the stack's loads discard, strict mode off, with Julia's two invalidation
# logs on. The loads in the workload's order, the solvers one package at a time. Per load:
#   `J <load> s=<seconds> compile=<s> recompile=<s>`
#   `J <load> invalidated n=<lost>/<valid before> owners: … | modules: …`  valid CodeInstances made invalid by the
#        load's new methods (a snapshot before and after; `modules` = the root module of each CodeInstance's method);
#   `J <load> causes: <module>=<n> …`  the root modules of the methods whose insertion invalidated them (Julia's
#        method-table log: each `jl_method_table_insert` tag after the MethodInstances it invalidated);
#   `J <load> rejected n=<k> owners: … | modules: …`  the loaded images' CodeInstances that failed validation
#        (`insert_backedges_callee`, `verify_methods` in the compiler's load-time log), and
#   `J <load> rejected-by: <module>=<n> …`  the root modules of the methods that now match the failed edges.
# Run by the harness: NDW_SCRIPT=scripts/p6_loadinv.jl run_workload.sh <tag> I   (strict off: no NDW_STRICT)
include(joinpath(@__DIR__, "diag.jl"))
const RU = Base.Compiler.ReinferUtils
const GF = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
tally(xs) = (d = Dict{Any,Int}(); for x in xs; d[x] = get(d, x, 0) + 1; end; join(["$k=$v" for (k, v) in sort!(collect(d); by = x -> -last(x))][1:min(end, 16)], " "))
ownerstr(ci) = ci.owner === nothing ? "nothing" : repr(ci.owner)
rootof(m) = m isa Method ? nameof(Base.moduleroot(m.module)) : :toplevel
cimod(ci) = (d = ci.def; mi = d isa Core.MethodInstance ? d : d.def; rootof(mi.def))
function load(name, ex)
    v0, _ = NDWDiag.snapshot()
    empty!(GF); RU.debug_method_invalidation(true)
    st = @timed Core.eval(Main, ex)
    rl = RU._jl_debug_method_invalidation[]; RU.debug_method_invalidation(false)
    gl = copy(GF)
    r = NDWDiag.lost(v0)
    lostf = [ci for ci in v0 if ci.max_world != typemax(UInt) && ci.owner !== nothing]
    println("J ", name, " s=", round(st.time; digits = 2), " compile=", round(st.compile_time; digits = 2),
            " recompile=", round(st.recompile_time; digits = 2))
    println("J ", name, " invalidated n=", r.n, "/", r.of, " owners: ", r.owners, " | modules: ", r.modules)
    println("J ", name, " invalidated-facts n=", length(lostf), " modules: ", tally(cimod.(lostf)))
    # causes from the method-table log: count the MethodInstances before each insertion tag
    causes = Symbol[]; pending = 0
    for i in eachindex(gl)
        x = gl[i]
        if x isa Core.MethodInstance
            pending += 1
        elseif x isa String && x == "jl_method_table_insert" && i > 1 && gl[i-1] isa Method
            append!(causes, fill(rootof(gl[i-1]), pending)); pending = 0
        end
    end
    println("J ", name, " causes: ", tally(causes), pending > 0 ? " unattributed=$pending" : "")
    rej = Core.CodeInstance[]; by = Symbol[]
    for i in eachindex(rl)
        x = rl[i]
        x isa String || continue
        if x == "insert_backedges_callee" && i + 2 <= length(rl)
            ci = rl[i+1]; ci isa Core.CodeInstance && push!(rej, ci)
            ms = rl[i+2]
            if ms isa AbstractVector
                for m in ms
                    mm = m isa Method ? m : m isa Core.MethodMatch ? m.method : nothing
                    mm === nothing || push!(by, rootof(mm))
                end
            end
        elseif x == "verify_methods" && i > 1
            ci = rl[i-1]; ci isa Core.CodeInstance && push!(rej, ci)
        end
    end
    unique!(rej)
    println("J ", name, " rejected n=", length(rej), " owners: ", tally(ownerstr.(rej)), " | modules: ", tally(cimod.(rej)))
    println("J ", name, " rejected-by: ", tally(by))
    fr = filter(ci -> ci.owner !== nothing, rej)
    println("J ", name, " rejected-facts n=", length(fr), " modules: ", tally(cimod.(fr)))
    flush(stdout)
end
if get(ENV, "NDW_TRAITWORLD", "0") == "1"           # setting U has no TraitWorld: the plain baseline of the same loads
    load("TraitWorld", :(using TraitWorld))
    println("STRICT ", Base.invokelatest(() -> getfield(Main, :TraitWorld).STRICT[]) ? "on" : "off")
end
load("Graphs,NetworkDynamics", :(using Graphs, NetworkDynamics))
load("OrdinaryDiffEqTsit5", :(using OrdinaryDiffEqTsit5))
load("OrdinaryDiffEqRosenbrock", :(using OrdinaryDiffEqRosenbrock))
load("DiffEqCallbacks", :(using DiffEqCallbacks))
load("SymbolicIndexingInterface", :(using SymbolicIndexingInterface))
load("CairoMakie,GraphMakie,Observables", :(using CairoMakie, GraphMakie, Observables))
