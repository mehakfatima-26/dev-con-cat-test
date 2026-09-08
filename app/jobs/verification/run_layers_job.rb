module Verification
  class RunLayersJob < ApplicationJob
    queue_as :critical

    def perform(verification_run_id)
      run = VerificationRun.find(verification_run_id)

      if run.status.in?(%w[completed partial])
        if run.certificate.blank?
          certificate = Certificates::Issuer.call(run)
          Verification::ActivityPublisher.publish_final_verdict(run, certificate)
        end
        return
      end

      run.update!(status: :running) if run.pending?
      starved = dispatch_all(run)
      finalize(run, starved)
    end

    private

    def dispatch_all(run)
      layers = [ "duplicate_detection" ] + (run.enabled_modules_snapshot - [ "duplicate_detection" ])
      starved = false

      layers.each do |key|
        if starved || insufficient_credits?(run, key)
          starved = true
          upsert_layer_result(run, key, state: :errored, detail: "#{key} not run: insufficient credits")
          next
        end

        result = Verification::RunLayer.new(verification_run: run, layer_key: key).call

        if key == "duplicate_detection" && result.result == "fail"
          skip_remaining(run, layers - [ key ])
          break
        end
      end

      starved
    end

    def skip_remaining(run, keys)
      keys.each do |key|
        upsert_layer_result(run, key, state: :skipped, detail: "Skipped: exact duplicate already ended this run")
      end
    end

    def upsert_layer_result(run, key, state:, detail:)
      row = LayerResult.find_or_initialize_by(verification_run: run, layer_key: key)
      row.update!(state: state, detail: detail, result: nil, weight: nil)
    end

    def insufficient_credits?(run, layer_key)
      run.lead.account.credits_remaining < DetectionLayer.cost(layer_key)
    end

    def finalize(run, starved)
      outcome = ConsensusEngine.call(layer_results: run.layer_results, policy_version: run.policy_version)
      verdict = (starved && outcome[:verdict] == "accept") ? "review" : outcome[:verdict]

      run.update!(
        verdict: verdict,
        verdict_reason: outcome[:reason] || "No adverse signals",
        score: outcome[:score],
        reasons: outcome[:reasons],
        status: starved ? :partial : :completed,
        finished_at: Time.current,
        credits_charged: run.credit_transactions.sum(:amount).abs
      )

      certificate = Certificates::Issuer.call(run)
      Verification::ActivityPublisher.publish_final_verdict(run, certificate)

      create_crm_record(run) if run.accept_verdict?
    end

    def create_crm_record(run)
      lead = run.lead
      return if CrmRecord.exists?(lead: lead)

      CrmRecord.create!(
        account: lead.account, lead: lead, crm_id: "CRM-#{lead.lead_id}",
        first_name: lead.first_name, last_name: lead.last_name,
        email: lead.email, phone: lead.phone, crm_created_at: Time.current
      )
    end
  end
end
