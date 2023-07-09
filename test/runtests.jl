# This file is a part of BAT.jl, licensed under the MIT License (MIT).

using Test

@info "Running tests with $(Base.Threads.nthreads()) Julia threads active."

import Pkg
if "PyCall" in keys(Pkg.project().dependencies)
    import PyCall
    @info "Python configuration:" get(ENV, "PYTHON", "not set") PyCall.PYTHONHOME PyCall.python PyCall.conda
end

import Logging
import TerminalLoggers
Logging.global_logger(TerminalLoggers.TerminalLogger(stderr, Logging.Error))

import AbstractMCMC
AbstractMCMC.setprogress!(false)

# ToDo - Temporary:
using BAT: AbstractMeasureOrDensity, BATMeasure, BATDensity

Test.@testset "Package BAT" begin
    include("test_aqua.jl")
    include("utils/test_utils.jl")
    include("rngs/test_rngs.jl")
    include("distributions/test_distributions.jl")
    include("variates/test_variates.jl")
    include("transforms/test_transforms.jl")
    include("densities/test_densities.jl")
    include("initvals/test_initvals.jl")
    include("statistics/test_statistics.jl")
    include("optimization/test_optimization.jl")
    include("samplers/test_samplers.jl")
    include("io/test_io.jl")
    include("plotting/test_plotting.jl")
    include("integration/test_integration.jl")
end
