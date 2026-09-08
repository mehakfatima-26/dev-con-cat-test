module Verification
  class ActivityPublisher
    REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

    def self.channel_for(lead)
      "lead_activity:#{lead.id}"
    end

    def self.publish_layer_result(layer_result)
      publish(layer_result.verification_run.lead,
        type: "layer_result", id: layer_result.id, layer: layer_result.layer_key,
        verdict: layer_result.result || layer_result.state, detail: layer_result.detail)
    end

    def self.publish_final_verdict(run, certificate)
      publish(run.lead, type: "final_verdict", verdict: run.verdict, score: run.score, reasons: run.reasons,
        certificate_serial: certificate&.serial)
    end

    def self.publish(lead, payload)
      Sidekiq.redis { |conn| conn.publish(channel_for(lead), payload.to_json) }
    rescue StandardError => e
      Rails.logger.warn("[ActivityPublisher] publish failed for lead #{lead.id}: #{e.message}")
    end

    def self.new_subscriber_connection
      Redis.new(url: REDIS_URL)
    end
  end
end
