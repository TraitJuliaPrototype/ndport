# S7 (PB-7): Polyester.@batch's expansion of the loop the batch function would hold, read against the
# definition check (TraitWorld/src/checks.jl: a closure capturing a trait object is checked, :101–111;
# a trait object stored in a tuple or passed bare to an ordinary function is refused, :150–158, :191–195).
using NetworkDynamics: Polyester   # ND's own dependency
ex = @macroexpand Polyester.@batch for i in 1:length(batch)
    _vertex!(m, fg, batch, i, du, u, o, inbufs, p, t)
end
println(Base.remove_linenums!(ex))
