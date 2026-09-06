module Verification
  class Runner
    def self.call(lead, async: true)
      new(lead, async: async).call
    end

    def initialize(lead, async: true)
      @lead = lead
      @async = async
    end

    def call
      run = VerificationRun.create!(
        lead: lead,
        policy_version: policy_version,
        enabled_modules_snapshot: account.enabled_modules,
        status: :pending,
        started_at: Time.current
      )

      async ? RunLayersJob.perform_later(run.id) : RunLayersJob.perform_now(run.id)
      run
    end

    private

    attr_reader :lead, :async

    def account
      lead.account
    end

    def consensus_policy
      ConsensusPolicy.find_by(account: account) || ConsensusPolicy.find_by(account: nil) ||
        raise("No consensus policy configured for #{account.account_id}, and no global default exists")
    end

    def policy_version
      consensus_policy.active_policy_version ||
        raise("#{consensus_policy.name} has no active policy version")
    end
  end
end
