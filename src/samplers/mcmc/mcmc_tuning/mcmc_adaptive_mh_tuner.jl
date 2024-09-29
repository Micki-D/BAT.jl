# This file is a part of BAT.jl, licensed under the MIT License (MIT).

# ToDo: Add literature references to AdaptiveMHTuning docstring.
"""
    struct AdaptiveMHTuning <: MHProposalDistTuning

Adaptive MCMC tuning strategy for Metropolis-Hastings samplers.

Adapts the proposal function based on the acceptance ratio and covariance
of the previous samples.

Constructors:

* ```$(FUNCTIONNAME)(; fields...)```

Fields:

$(TYPEDFIELDS)
"""
@with_kw struct AdaptiveMHTuning <: MHProposalDistTuning
    "Controls the weight given to new covariance information in adapting the
    proposal distribution."
    λ::Float64 = 0.5

    "Metropolis-Hastings acceptance ratio target, tuning will try to adapt
    the proposal distribution to bring the acceptance ratio inside this interval."
    α::IntervalSets.ClosedInterval{Float64} = ClosedInterval(0.15, 0.35)

    "Controls how much the spread of the proposal distribution is
    widened/narrowed depending on the current MH acceptance ratio."
    β::Float64 = 1.5

    "Interval for allowed scale/spread of the proposal distribution."
    c::IntervalSets.ClosedInterval{Float64} = ClosedInterval(1e-4, 1e2)

    "Reweighting factor. Take accumulated sample statistics of previous
    tuning cycles into account with a relative weight of `r`. Set to
    `0` to completely reset sample statistics between each tuning cycle."
    r::Real = 0.5
end

export AdaptiveMHTuning

# TODO: MD, make immutable and use Accessors.jl
mutable struct AdaptiveMHTrafoTunerState{
    S<:MCMCBasicStats
} <: AbstractMCMCTunerState
    tuning::AdaptiveMHTuning
    stats::S
    iteration::Int
    scale::Float64
end

struct AdaptiveMHProposalTunerState <: AbstractMCMCTunerState end

(tuning::AdaptiveMHTuning)(chain_state::MCMCChainState) = AdaptiveMHTrafoTunerState(tuning, chain_state), AdaptiveMHProposalTunerState()

# TODO: MD, what should the default be? 
default_adaptive_transform(tuning::AdaptiveMHTuning) = TriangularAffineTransform()

function AdaptiveMHTrafoTunerState(tuning::AdaptiveMHTuning, chain_state::MCMCChainState)
    m = totalndof(varshape(mcmc_target(chain_state)))
    scale = 2.38^2 / m
    AdaptiveMHTrafoTunerState(tuning, MCMCBasicStats(chain_state), 1, scale)
end


AdaptiveMHProposalTunerState(tuning::AdaptiveMHTuning, chain_state::MCMCChainState) = AdaptiveMHProposalTunerState()


create_trafo_tuner_state(tuning::AdaptiveMHTuning, chain_state::MCMCChainState, iteration::Integer) = AdaptiveMHTrafoTunerState(tuning, chain_state)

create_proposal_tuner_state(tuning::AdaptiveMHTuning, chain_state::MCMCChainState, iteration::Integer) = AdaptiveMHProposalTunerState()


function mcmc_tuning_init!!(tuner_state::AdaptiveMHTrafoTunerState, chain_state::MCMCChainState, max_nsteps::Integer)
    n = totalndof(varshape(mcmc_target(chain_state)))

    proposaldist = chain_state.proposal.proposaldist
    Σ_unscaled = _approx_cov(proposaldist, n)
    Σ = Σ_unscaled * tuner_state.scale
    
    S = cholesky(Positive, Σ)
    
    chain_state.f_transform = Mul(S.L)

    nothing
end

mcmc_tuning_init!!(tuner_state::AdaptiveMHProposalTunerState, chain_state::MCMCChainState, max_nsteps::Integer) = nothing


mcmc_tuning_reinit!!(tuner_state::AdaptiveMHTrafoTunerState, chain_state::MCMCChainState, max_nsteps::Integer) = nothing

mcmc_tuning_reinit!!(tuner_state::AdaptiveMHProposalTunerState, chain_state::MCMCChainState, max_nsteps::Integer) = nothing


function mcmc_tuning_postinit!!(tuner::AdaptiveMHTrafoTunerState, chain_state::MCMCChainState, samples::DensitySampleVector)
    # The very first samples of a chain can be very valuable to init tuner
    # stats, especially if the chain gets stuck early after:
    stats = tuner.stats
    append!(stats, samples)
end

mcmc_tuning_postinit!!(tuner_state::AdaptiveMHProposalTunerState, chain_state::MCMCChainState, samples::DensitySampleVector) = nothing


function mcmc_tune_post_cycle!!(tuner::AdaptiveMHTrafoTunerState, mc_state::MCMCChainState, samples::DensitySampleVector)
    tuning = tuner.tuning
    stats = tuner.stats
    stats_reweight_factor = tuning.r
    reweight_relative!(stats, stats_reweight_factor)
    append!(stats, samples)

    proposaldist = mc_state.proposal.proposaldist

    α_min = minimum(tuning.α)
    α_max = maximum(tuning.α)

    c_min = minimum(tuning.c)
    c_max = maximum(tuning.c)

    β = tuning.β

    t = tuner.iteration
    λ = tuning.λ
    c = tuner.scale

    f_transform = mc_state.f_transform
    A = f_transform.A
    Σ_old = A * A'

    S = convert(Array, stats.param_stats.cov)
    a_t = 1 / t^λ
    new_Σ_unscal = (1 - a_t) * (Σ_old/c) + a_t * S

    α = eff_acceptance_ratio(mc_state)

    max_log_posterior = stats.logtf_stats.maximum

    if α_min <= α <= α_max
        mc_state.info = MCMCChainStateInfo(mc_state.info, tuned = true)
        @debug "MCMC chain $(mc_state.info.id) tuned, acceptance ratio = $(Float32(α)), proposal scale = $(Float32(c)), max. log posterior = $(Float32(max_log_posterior))"
    else
        mc_state.info = MCMCChainStateInfo(mc_state.info, tuned = false)
        @debug "MCMC chain $(mc_state.info.id) *not* tuned, acceptance ratio = $(Float32(α)), proposal scale = $(Float32(c)), max. log posterior = $(Float32(max_log_posterior))"

        if α > α_max && c < c_max
            tuner.scale = c * β
        elseif α < α_min && c > c_min
            tuner.scale = c / β
        end
    end

    Σ_new = new_Σ_unscal * tuner.scale
    S_new = cholesky(Positive, Σ_new)
    
    mc_state.f_transform = Mul(S_new.L)
    
    tuner.iteration += 1

    nothing
end

mcmc_tune_post_cycle!!(tuner::AdaptiveMHProposalTunerState, mc_state::MCMCChainState, samples::DensitySampleVector) = nothing


mcmc_tuning_finalize!!(tuner::AdaptiveMHTrafoTunerState, mc_state::MCMCChainState) = nothing

mcmc_tuning_finalize!!(tuner::AdaptiveMHProposalTunerState, mc_state::MCMCChainState) = nothing


tuning_callback(::AdaptiveMHTrafoTunerState) = nop_func

tuning_callback(::AdaptiveMHProposalTunerState) = nop_func

# add a boold to return if the transfom changes 
function mcmc_tune_post_step!!(
    tuner::AdaptiveMHTrafoTunerState,
    chain_state::MCMCChainState,
    p_accept::Real
)
    return chain_state, tuner, false
end

function mcmc_tune_post_step!!(
    tuner::AdaptiveMHProposalTunerState,
    chain_state::MCMCChainState,
    p_accept::Real
)
    return chain_state, tuner, false
end
