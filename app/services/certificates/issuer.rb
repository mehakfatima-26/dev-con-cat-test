module Certificates
  class Issuer
    def self.call(run)
      new(run).call
    end

    def initialize(run)
      @run = run
      @issued_at = Time.current
    end

    def call
      Certificate.create!(
        verification_run: run,
        serial: generate_serial,
        payload: payload,
        payload_sha256: payload_sha256,
        prev_sha256: prev_sha256,
        signature: signature,
        incomplete: run.partial?,
        incomplete_reason: incomplete_reason,
        issued_at: issued_at
      )
    end

    private

    attr_reader :run, :issued_at

    def lead
      run.lead
    end

    def account
      lead.account
    end

    def payload
      @payload ||= {
        "lead_id" => lead.lead_id,
        "account_id" => account.account_id,
        "verdict" => run.verdict,
        "score" => run.score.to_f,
        "verdict_reason" => run.verdict_reason,
        "reasons" => run.reasons,
        "policy_version" => {
          "consensus_policy" => run.policy_version.consensus_policy.name,
          "version" => run.policy_version.version
        },
        "layers" => layer_summaries,
        "not_enabled_layers" => DetectionLayer::KEYS - run.enabled_modules_snapshot,
        "trusted_form_cert_url" => lead.trusted_form_cert_url,
        "landing_page_url" => lead.landing_page_url,
        "credits_charged" => run.credits_charged,
        "captured_at" => lead.captured_at.iso8601,
        "issued_at" => issued_at.iso8601
      }
    end

    def layer_summaries
      run.layer_results.order(:layer_key).map do |lr|
        {
          "layer_key" => lr.layer_key,
          "state" => lr.state,
          "result" => lr.result,
          "weight" => lr.weight&.to_f,
          "detail" => lr.detail
        }
      end
    end

    def payload_sha256
      @payload_sha256 ||= Digest::SHA256.hexdigest(Certificate.canonical_json(payload))
    end

    def prev_sha256
      @prev_sha256 ||= Certificate.joins(verification_run: :lead)
        .where(leads: { account_id: account.id })
        .order(id: :desc)
        .first&.payload_sha256
    end

    def signature
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{payload_sha256}:#{prev_sha256}")
    end

    def generate_serial
      "CERT-#{SecureRandom.alphanumeric(12).upcase}"
    end

    def incomplete_reason
      return nil unless run.partial?

      starved_keys = run.layer_results.where(state: :errored)
        .where("detail LIKE ?", "%insufficient credits%")
        .pluck(:layer_key)

      "Account ran out of credits mid-run -- #{starved_keys.size} layer(s) not run: #{starved_keys.join(', ')}"
    end
  end
end
