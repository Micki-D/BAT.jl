@with_kw struct TransformedRAMTuner <: MCMCTuningAlgorithm #TODO: rename to RAMTuning
    target_acceptance::Float64 = 0.234 #TODO AC: how to pass custom intitial value for cov matrix?
    σ_target_acceptance::Float64 = 0.05
    gamma::Float64 = 2/3
end

@with_kw mutable struct TransformedRAMTunerState <: AbstractMCMCTunerInstance # TODO no @with_kw
    config::TransformedRAMTuner # TODO Rename to "tuning"
    nsteps::Int = 0
end
TransformedRAMTunerState(ram::TransformedRAMTuner) = TransformedRAMTunerState(config = ram)

get_tuner(tuning::TransformedRAMTuner, chain::MCMCIterator) = TransformedRAMTunerState(tuning)# TODO rename to create_tuner_state(tuning::RAMTuner, mc_state::MCMCState, n_steps_hint::Integer)


function tuning_init!(tuner::TransformedRAMTunerState, chain::MCMCIterator, max_nsteps::Integer)
    chain.info = MCMCIteratorInfo(chain.info, tuned = false) # TODO ?
    tuner.nsteps = 0
    
    return nothing
end


tuning_postinit!(tuner::TransformedRAMTunerState, chain::MCMCIterator, samples::DensitySampleVector) = nothing

# TODO AC: is this still needed?
# function tuning_postinit!(tuner::TransformedProposalCovTuner, chain::MCMCIterator, samples::DensitySampleVector)
#     # The very first samples of a chain can be very valuable to init tuner
#     # stats, especially if the chain gets stuck early after:
#     stats = tuner.stats
#     append!(stats, samples)
# end

tuning_reinit!(tuner::TransformedRAMTunerState, chain::MCMCIterator, max_nsteps::Integer) = nothing





function tuning_update!(tuner::TransformedRAMTunerState, chain::MCMCIterator, samples::DensitySampleVector)
    α_min, α_max = map(op -> op(1, tuner.config.σ_target_acceptance), [-,+]) .* tuner.config.target_acceptance
    α = eff_acceptance_ratio(chain)

    max_log_posterior = maximum(samples.logd)

    if α_min <= α <= α_max
        chain.info = MCMCIteratorInfo(chain.info, tuned = true)
        @debug "MCMC chain $(chain.info.id) tuned, acceptance ratio = $(Float32(α)), max. log posterior = $(Float32(max_log_posterior))"
    else
        chain.info = MCMCIteratorInfo(chain.info, tuned = false)
        @debug "MCMC chain $(chain.info.id) *not* tuned, acceptance ratio = $(Float32(α)), max. log posterior = $(Float32(max_log_posterior))"
    end
end

tuning_finalize!(tuner::TransformedRAMTunerState, chain::MCMCIterator) = nothing

# tuning_callback(::TransformedRAMTuner) = nop_func



default_adaptive_transform(tuner::TransformedRAMTuner) = TriangularAffineTransform() 

function tune_mcmc_transform!!(
    tuner::TransformedRAMTunerState, 
    transform::Mul{<:LowerTriangular}, #AffineMaps.AbstractAffineMap,#{<:typeof(*), <:LowerTriangular{<:Real}},
    p_accept::Real,
    sample_z,
    stepno::Int,
    context::BATContext
)
    @unpack target_acceptance, gamma = tuner.config
    n = size(sample_z.v[1],1)
    η = min(1, n * tuner.nsteps^(-gamma))

    s_L = transform.A

    u = sample_z.v[2] - sample_z.v[1] # proposed - current
    M = s_L * (I + η * (p_accept - target_acceptance) * (u * u') / norm(u)^2 ) * s_L'

    S = cholesky(Positive, M)
    transform_new  = Mul(S.L)

    tuner.nsteps += 1

    return (tuner, transform_new, true)
end
