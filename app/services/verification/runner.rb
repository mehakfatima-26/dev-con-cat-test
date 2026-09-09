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

    def policy_version
      ConsensusPolicy.active_version_for(account) ||
        raise("No active consensus policy version for #{account.account_id}, and no global default exists")
    end
  end
end
