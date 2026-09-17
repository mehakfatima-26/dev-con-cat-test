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
      run = reserve_and_create_run
      return nil unless run

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

    def reserve_and_create_run
      run = nil

      account.with_lock do
        cost = ConsensusEngine.critical_layers_cost_for(account: account, policy_version: policy_version)
        next if account.credits_remaining < cost

        run = VerificationRun.create!(
          lead: lead,
          policy_version: policy_version,
          enabled_modules_snapshot: account.enabled_modules,
          credits_reserved: cost,
          status: :pending,
          started_at: Time.current
        )
      end

      run
    end
  end
end
