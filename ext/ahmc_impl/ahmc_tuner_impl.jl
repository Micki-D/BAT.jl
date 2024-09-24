# This file is a part of BAT.jl, licensed under the MIT License (MIT).


mutable struct AHMCTunerState{A<:AdvancedHMC.AbstractAdaptor} <: AbstractMCMCTunerInstance
    tuning::HMCTuning
    target_acceptance::Float64
    adaptor::A
end

function (tuning::HMCTuning)(mc_state::HMCState)
    θ = first(mc_state.samples).v
    adaptor = ahmc_adaptor(tuning, mc_state.proposal.hamiltonian.metric, mc_state.proposal.kernel.τ.integrator, θ)
    AHMCTunerState(tuning, tuning.target_acceptance, adaptor)
end


function BAT.tuning_init!(tuner::AHMCTunerState, mc_state::HMCState, max_nsteps::Integer)
    AdvancedHMC.Adaptation.initialize!(tuner.adaptor, Int(max_nsteps - 1))
    nothing
end

BAT.tuning_postinit!(tuner::AHMCTunerState, mc_state::HMCState, samples::DensitySampleVector) = nothing

function BAT.tuning_reinit!(tuner::AHMCTunerState, mc_state::HMCState, max_nsteps::Integer)
    AdvancedHMC.Adaptation.initialize!(tuner.adaptor, Int(max_nsteps - 1))
    nothing
end

function BAT.tuning_update!(tuner::AHMCTunerState, mc_state::HMCState, samples::DensitySampleVector)
    max_log_posterior = maximum(samples.logd)
    accept_ratio = eff_acceptance_ratio(mc_state)
    if accept_ratio >= 0.9 * tuner.target_acceptance
        mc_state.info = MCMCStateInfo(mc_state.info, tuned = true)
        @debug "MCMC chain $(mc_state.info.id) tuned, acceptance ratio = $(Float32(accept_ratio)), integrator = $(mc_state.proposal.τ.integrator), max. log posterior = $(Float32(max_log_posterior))"
    else
        mc_state.info = MCMCStateInfo(mc_state.info, tuned = false)
        @debug "MCMC chain $(mc_state.info.id) *not* tuned, acceptance ratio = $(Float32(accept_ratio)), integrator = $(mc_state.proposal.τ.integrator), max. log posterior = $(Float32(max_log_posterior))"
    end
    nothing
end

function BAT.tuning_finalize!(tuner::AHMCTunerState, mc_state::HMCState)
    adaptor = tuner.adaptor
    proposal = mc_state.proposal
    AdvancedHMC.finalize!(adaptor)
    proposal.hamiltonian = AdvancedHMC.update(proposal.hamiltonian, adaptor)
    proposal.kernel = AdvancedHMC.update(proposal.kernel, adaptor)
    nothing
end

BAT.tuning_callback(tuner::AHMCTunerState) = AHMCTunerStateCallback(tuner)



struct AHMCTunerStateCallback{T<:AHMCTunerState} <: Function
    tuner::T
end


function (callback::AHMCTunerStateCallback)(::Val{:mcmc_step}, mc_state::HMCState)
    adaptor = callback.tuner.adaptor
    proposal = mc_state.proposal
    tstat = AdvancedHMC.stat(proposal.transition)

    AdvancedHMC.adapt!(adaptor, proposal.transition.z.θ, tstat.acceptance_rate)
    proposal.hamiltonian = AdvancedHMC.update(proposal.hamiltonian, adaptor)
    proposal.kernel = AdvancedHMC.update(proposal.kernel, adaptor)
    tstat = merge(tstat, (is_adapt =true,))

    nothing
end
