# This file is a part of BAT.jl, licensed under the MIT License (MIT).

module BATAdvancedHMCExt

using AdvancedHMC

using BAT
BAT.pkgext(::Val{:AdvancedHMC}) = BAT.PackageExtension{:AdvancedHMC}()

using Random
using DensityInterface
using HeterogeneousComputing, AutoDiffOperators

using BAT: MeasureLike, BATMeasure

using BAT: get_context, get_adselector, _NoADSelected
using BAT: getproposal, mcmc_target
using BAT: MCMCChainState, HMCState, HamiltonianMC, HMCProposalState, MCMCChainStateInfo, MCMCChainPoolInit, MCMCMultiCycleBurnin, AbstractMCMCTunerState
using BAT: _current_sample_idx, _proposed_sample_idx, _cleanup_samples
using BAT: AbstractTransformTarget
using BAT: RNGPartition, get_rng, set_rng!
using BAT: mcmc_step!!, nsamples, nsteps, samples_available, eff_acceptance_ratio
using BAT: get_samples!, get_mcmc_tuning, reset_rng_counters!
using BAT: create_trafo_tuner_state, create_proposal_tuner_state, mcmc_tuning_init!!, mcmc_tuning_postinit!!, mcmc_tuning_reinit!!, mcmc_tune_transform_post_cycle!!, transform_mcmc_tuning_finalize!!, tuning_callback
using BAT: totalndof, measure_support, checked_logdensityof
using BAT: CURRENT_SAMPLE, PROPOSED_SAMPLE, INVALID_SAMPLE, ACCEPTED_SAMPLE, REJECTED_SAMPLE

using BAT: HamiltonianMC
using BAT: AHMCSampleID, AHMCSampleIDVector
using BAT: HMCMetric, DiagEuclideanMetric, UnitEuclideanMetric, DenseEuclideanMetric
using BAT: HMCTuning, MassMatrixAdaptor, StepSizeAdaptor, NaiveHMCTuning, StanHMCTuning

using ValueShapes: varshape

using Accessors: @set


BAT.ext_default(::BAT.PackageExtension{:AdvancedHMC}, ::Val{:DEFAULT_INTEGRATOR}) = AdvancedHMC.Leapfrog(NaN)
BAT.ext_default(::BAT.PackageExtension{:AdvancedHMC}, ::Val{:DEFAULT_TERMINATION_CRITERION}) = AdvancedHMC.GeneralisedNoUTurn()


include("ahmc_impl/ahmc_config_impl.jl")
include("ahmc_impl/ahmc_sampler_impl.jl")
include("ahmc_impl/ahmc_tuner_impl.jl")


end # module BATAdvancedHMCExt
