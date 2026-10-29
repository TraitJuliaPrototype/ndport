# R1 (E-237), part 1b: which of the names in <names.tsv> (scripts/r1_gm_names.jl) MakieCompat or TraitMakie define.
#     julia --project=env_r1plot scripts/r1_gm_check.jl logs/r1/graphmakie-names-U.tsv <out.tsv>
using TraitMakie, MakieCompat
rows = [split(l, '\t') for l in eachline(ARGS[1])]
open(ARGS[2], "w") do io
    for r in rows
        s = Symbol(r[1])
        where = isdefined(MakieCompat, s) ? "MakieCompat" : isdefined(TraitMakie, s) ? "TraitMakie" :
                isdefined(TraitMakie.OldAPI, s) ? "TraitMakie.OldAPI" : isdefined(TraitMakie.PlotCore, s) ? "PlotCore" : "-"
        println(io, join(r, '\t'), '\t', where)
    end
end
n = count(l -> endswith(l, "\t-"), eachline(ARGS[2]))
println("R1 missing ", n, " of ", length(rows))
