# P6 checks C and H (E-155; writeup/plans/2026-10-21-ndport-inside-out.md §3.1), one session, run by the harness
# (NDW_SCRIPT=scripts/p6_census.jl, setting I, NDW_STRICT=1, JULIA_FACTS_DISPATCH_PROFILE=1).
#
# C, the census, after the whole stack has loaded and the workload's first pass a–e has run: every loaded package
# (root modules; extensions apart, attributed to their parents). Per package:
#   `CP <pkg> wrapped=<0|1> methods=<n> pirates=<k> joint=<j> generated=<g>`
#   wrapped: its root module is a trait module (TraitWorld.is_trait_world);
#   pirates: methods TraitWorld.owned_method refuses (joint owners counted), the strict mode's rule 3;
#   joint:   methods that are pirates without joint owners and owned with them (they rest on a declaration).
# One `CPIRATE <pkg> <sig> <file:line> | fowner=<owner of the function> towners=<owners of the types>` per pirate,
# one `CJOINT <pkg> <sig> <file:line>` per joint method. Extensions as `CX <ext> parent=<pkg> ...`, same columns.
# The control: `C0 <pkg> methods= pirates= generated=` for P0's 17 packages, by P0's counting (p3_census.jl,
# joint owners not counted), which must reproduce ndport/logs/p3/census-P0.log at S0.
#
# H, the dispatch profile: steps c, d, e of an "again" pass with the profile reset before them and printed after
# (stderr, `-- dynamic calls by callee method`); scripts/p6_profile_summary.py groups it by the callee's module.
#
# Also prints strict mode's state (`STRICT on|off`) and, at S6 (NDW_FOLD=1), the fold check of Tsit5's tableau.
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
using CairoMakie, GraphMakie, Observables
println("STRICT ", TraitWorld.STRICT[] ? "on" : "off")
include(joinpath(@__DIR__, "workload_steps.jl"))

# ---- the workload's first pass, steps a–e (untimed), so that the census sees what the workload compiled ------------
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw); d = NDW.step_d(nw, c.s); e = NDW.step_e(nw, d.sol)
NDW.digest_d(d)

# ---- H: steps c–e again, profiled -------------------------------------------------------------------------------------
const PROF = get(ENV, "JULIA_FACTS_DISPATCH_PROFILE", "0") == "1"
NDW.PASS[] = "again"
a = NDW.step_a(:swing); nw = NDW.step_b(a)
PROF && ccall(:jl_facts_dispatch_profile_reset, Cvoid, ())
c = NDW.step_c(nw); d = NDW.step_d(nw, c.s); e = NDW.step_e(nw, d.sol)
if PROF
    flush(stdout); flush(stderr)
    println(stderr, "\n== H: the profile of steps c-e, again pass"); flush(stderr)
    ccall(:jl_facts_dispatch_profile_print, Cvoid, ())
    println(stderr, "== H end"); flush(stderr)
    ccall(:jl_facts_dispatch_profile_reset, Cvoid, ())
end
NDW.digest_d(d)

# ---- the fold check (S6): does Tsit5's per-step tableau construction fold under the facts owner? ------------------
if get(ENV, "NDW_FOLD", "0") == "1"
    include(joinpath(@__DIR__, "p6_fold.jl"))
end

# ---- C: the census --------------------------------------------------------------------------------------------------
const TW = TraitWorld
"rule 3 without joint owners: the definer itself owns the function or a type in every alternative (P0's counting)"
function owned_alone(m::Method)
    definer = TW.owner(m.module)
    for s in TW._sig_alternatives(m.sig)
        any(o -> o === definer, TW.sig_owners(s)) || return false
    end
    return true
end
ownername(o) = o isa Module ? string(nameof(o)) : string(o)
function fowner(m::Method)
    ft = Base.unwrap_unionall(m.sig)
    ft isa DataType && !isempty(ft.parameters) || return "?"
    f = ft.parameters[1]
    f isa DataType ? ownername(TW.owner(f.name.module)) : "?"
end
towners(m::Method) = join(sort!(unique!([ownername(o) for o in TW.sig_owners(Tuple{Base.unwrap_unionall(m.sig).parameters[2:end]...})])), ",")

struct Row; methods::Int; pirates::Vector{String}; joint::Vector{String}; generated::Int; end
rows = Dict{Module,Row}()
alone_pirates = Dict{Symbol,Int}()
Base.visit(Core.methodtable) do m
    m isa Method || return
    r = Base.moduleroot(m.module)
    (r === Base || r === Core || r === Main || TW.owner(r) === :Julia) && return
    row = get!(() -> Row(0, String[], String[], 0), rows, r)
    pir = String[]; joi = String[]
    gen = isdefined(m, :generator) ? 1 : 0
    own = TW.owned_method(m)
    owned_alone(m) || (alone_pirates[nameof(r)] = get(alone_pirates, nameof(r), 0) + 1)
    loc = "$(m.file):$(m.line)"
    if !own
        push!(pir, "$(m.sig) $loc | fowner=$(fowner(m)) towners=$(try towners(m) catch; "?" end)")
    elseif !owned_alone(m)
        push!(joi, "$(m.sig) $loc")
    end
    rows[r] = Row(row.methods + 1, append!(row.pirates, pir), append!(row.joint, joi), row.generated + gen)
end
isext(r) = TW._extension_parent(r) !== nothing
wrapped(r) = TW.is_trait_world(r) ? 1 : 0
pkgs = sort!(collect(keys(rows)); by = r -> (isext(r), string(nameof(r))))
for r in pkgs
    row = rows[r]
    head = isext(r) ? "CX $(nameof(r)) parent=$(nameof(TW._extension_parent(r)))" : "CP $(nameof(r))"
    println(head, " wrapped=", wrapped(r), " methods=", row.methods, " pirates=", length(row.pirates), " joint=", length(row.joint), " generated=", row.generated)
end
println("C wrapped: ", join([string(nameof(r)) for r in pkgs if wrapped(r) == 1 && !isext(r)], " "))
println("C pirates in wrapped packages: ", sum((length(rows[r].pirates) for r in pkgs if wrapped(r) == 1 || (isext(r) && TW.is_trait_world(TW._extension_parent(r)))); init = 0))
println("C joint owners declared: ", join(["$(nameof(r)) => $(TW._joint_names(r))" for r in pkgs if !isempty(TW._joint_names(r))], "; "))
for r in pkgs, s in sort(rows[r].pirates); println("CPIRATE ", nameof(r), " ", s); end
for r in pkgs, s in sort(rows[r].joint); println("CJOINT ", nameof(r), " ", s); end

# the control: P0's 17 packages, P0's counting (joint owners not counted)
const P0PKGS = [:NetworkDynamics, :SciMLBase, :DiffEqBase, :OrdinaryDiffEqCore, :OrdinaryDiffEqTsit5, :OrdinaryDiffEqRosenbrock,
                :DiffEqCallbacks, :SymbolicIndexingInterface, :RecursiveArrayTools, :NonlinearSolve, :NonlinearSolveBase,
                :Graphs, :NetworkLayout, :GraphMakie, :Makie, :Observables, :Static]
byname = Dict(nameof(r) => r for r in pkgs if !isext(r))
let tot = 0
    for p in P0PKGS
        r = get(byname, p, nothing)
        r === nothing && (println("C0 $p not loaded"); continue)
        k = get(alone_pirates, p, 0); tot += k
        println("C0 $p methods=$(rows[r].methods) pirates=$k generated=$(rows[r].generated)")
    end
    println("C0 total pirates=", tot)
end
exit(0)
