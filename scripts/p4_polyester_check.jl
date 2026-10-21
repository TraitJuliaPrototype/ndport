# S7 (PB-7): does the definition check accept Polyester.@batch over a trait object in a bounded function?
using TraitWorld
using NetworkDynamics: Polyester
@trait_module module PolyCheck
using TraitWorld
using NetworkDynamics: Polyester
@trait Scale begin
    scale(s::Scale, x::Float64)::Float64
end
struct Twice end
scale(::Twice, x::Float64) = 2x
@implement Scale Twice
function run_batch!(s::Scale, out::Vector{Float64}, xs::Vector{Float64})
    Polyester.@batch for i in 1:length(xs)
        out[i] = scale(s, xs[i])
    end
    nothing
end
end
out = zeros(4); PolyCheck.run_batch!(PolyCheck.Twice(), out, [1.0, 2.0, 3.0, 4.0]); println("ran: ", out)
