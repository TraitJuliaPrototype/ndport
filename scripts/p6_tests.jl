# P6 check Q (E-155, the plan §3.1): the wrapped packages' own quick tests, the files whose dependencies are in the
# stack's manifest (no SafeTestsets, SciMLTesting, AllocCheck, Zygote, JET, Measurements or the shorthand sublibrary).
# Each file runs in a module of its own (as SafeTestsets does), from the loaded package's own `test/` directory, so the
# same script runs the P6 trees (env_p6test, depot-p6) and the registry's releases (env_p6test_u: the baseline).
#     julia --project=env_p6test   scripts/p6_tests.jl s2|s6
#     julia --project=env_p6test_u scripts/p6_tests.jl s2|s6
# Prints `TEST <pkg>/<file> pass=… fail=… error=… broken=…` per file, and each failure as Test reports it.
using Test
const GROUP = ARGS[1]
const FILES = GROUP == "s2" ? [
    :SymbolicIndexingInterface => ["example_test.jl", "fallback_test.jl", "parameter_timeseries_collection_test.jl",
        "problem_state_test.jl", "symbol_cache_test.jl", "trait_test.jl", "type_grouped_indexes_test.jl",
        "batched_interface_test.jl", "remake_test.jl"],
    :RecursiveArrayTools => ["Core/partitions_and_static_arrays.jl", "Core/copy_static_array_test.jl",
        "Core/named_array_partition_tests.jl", "Core/scimlstructures_test.jl", "Core/tabletraits.jl"],
    :SciMLBase => ["interpolation_tests.jl", "solution_interface.jl", "integrator_tests.jl", "callback_constructors.jl",
        "convert_tests.jl", "function_wrappers.jl", "problem_building_test.jl"],
] : GROUP == "s6" ? [
    :DiffEqBase => ["callbacks.jl"],
    :OrdinaryDiffEqTsit5 => ["runtests.jl"],
] : error("group s2 or s6")
for (p, _) in FILES; @eval using $p; end
pkgdir_of(p) = pkgdir(getfield(Main, p))
println("# p6_tests ", GROUP, " ", join(("$p=$(pkgdir_of(p))" for (p, _) in FILES), " "))
mutable struct Collector <: Test.AbstractTestSet
    description::String
    results::Vector{Any}
end
Collector(desc; kw...) = Collector(desc, Any[])
Test.record(c::Collector, r) = (push!(c.results, r); r)
Test.finish(c::Collector) = c
function counts(ts)
    c = Test.get_test_counts(ts)
    (; pass = c.passes + c.cumulative_passes, fail = c.fails + c.cumulative_fails,
       error = c.errors + c.cumulative_errors, broken = c.broken + c.cumulative_broken)
end
top = @testset Collector "p6 $GROUP" begin
    for (p, fs) in FILES, f in fs
        dir = joinpath(pkgdir_of(p), "test")
        m = Module(Symbol(replace(basename(f), ".jl" => "")))
        Core.eval(m, :(using Test))
        Core.eval(m, :(include(x) = Base.include($m, joinpath($(dirname(joinpath(dir, f))), x))))
        t0 = time()
        @testset Test.DefaultTestSet "$p/$f" begin
            Base.include(m, joinpath(dir, f))
        end
        println("# ", p, "/", f, " s=", round(time() - t0; digits = 1))
    end
end
for ts in top.results
    c = counts(ts)
    println("TEST ", ts.description, " pass=", c.pass, " fail=", c.fail, " error=", c.error, " broken=", c.broken)
end
