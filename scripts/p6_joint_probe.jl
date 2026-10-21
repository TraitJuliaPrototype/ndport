# P6 (E-155), the joint-owner probe of the inside-out plan §1.4: `@joint_owners` inside a package's
# `@trait_module begin … end` block, the form the wrap gives SciMLBase (TraitWorld's test/joint.jl declares only
# in a plain module). A package-like owner wrapped that way declares JPImpl; JPImpl (a trait module) defines the
# owner's function on the owner's type and Base.isempty on the owner's type: accepted, owned. JPOther, not named,
# defines the same: refused (OwnershipError). Prints `JP <check> <true|false>` and `JP all <true|false>`.
#     julia --project=env_p6 scripts/p6_joint_probe.jl
using TraitWorld
inner(e) = (while e isa LoadError; e = e.error; end; e)
caught(f) = try f(); nothing catch e; inner(e) end
top(ex) = Core.eval(Main, ex)

r = caught(() -> top(:(module JPCore
    using TraitWorld: TraitWorld, @trait_module, @joint_owners
    @trait_module begin
    @joint_owners JPImpl
    abstract type AbstractProb end
    struct Prob <: AbstractProb; x::Float64; end
    struct Box; v::Int; end
    function solve end
    solve(p::Prob, ::Nothing) = p.x
    end # @trait_module
end)))
ok = Dict{String,Bool}()
ok["owner wraps and declares"] = r === nothing
println("JP owner error: ", r === nothing ? "none" : sprint(showerror, r))
ok["declared"] = isdefined(Main, :JPCore) && TraitWorld._joint_names(JPCore) == (:JPImpl,)
ok["owner is a trait module"] = isdefined(Main, :JPCore) && TraitWorld.is_trait_world(JPCore)
r2 = caught(() -> top(:(@trait_module module JPImpl
    using TraitWorld
    using ..JPCore
    JPCore.solve(p::JPCore.AbstractProb) = 2 * p.x
    Base.isempty(b::JPCore.Box) = b.v == 0
    end)))
println("JP joint owner error: ", r2 === nothing ? "none" : sprint(showerror, r2))
ok["joint owner accepted"] = r2 === nothing
ok["owned_method"] = r2 === nothing && TraitWorld.owned_method(which(JPCore.solve, (JPCore.Prob,))) &&
                     TraitWorld.owned_method(which(isempty, (JPCore.Box,)))
r3 = caught(() -> top(:(@trait_module module JPOther
    using TraitWorld
    using ..JPCore
    JPCore.solve(p::JPCore.Prob) = 0.0
    end)))
println("JP stranger error: ", r3 === nothing ? "none" : typeof(r3))
ok["stranger refused"] = r3 isa TraitWorld.OwnershipError
for (k, v) in sort!(collect(ok)); println("JP ", k, " ", v); end
println("JP all ", all(values(ok)))
