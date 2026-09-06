class ConsensusEngine
  CONSENT_CRITICAL_LAYERS = %w[trustedform dnc duplicate_detection].freeze

  def self.call(layer_results:, policy_version:)
    new(layer_results: layer_results, policy_version: policy_version).call
  end

  def initialize(layer_results:, policy_version:)
    @layer_results = layer_results.reject { |r| r.state.to_s == "skipped" }
    @policy_version = policy_version
  end

  def call
    return reject_outcome if hard_stops.any?
    return review_floor_outcome if errored_critical_layers.any?

    threshold_outcome
  end

  private

  attr_reader :layer_results, :policy_version

  def thresholds
    policy_version.thresholds
  end

  def completed
    layer_results.select { |r| r.state.to_s == "completed" }
  end

  def hard_stops
    completed.select { |r| r.result.to_s == "fail" }
  end

  def errored_critical_layers
    layer_results.select { |r| r.state.to_s == "errored" && CONSENT_CRITICAL_LAYERS.include?(r.layer_key) }
  end

  def warn_rows
    completed.select { |r| r.result.to_s == "warn" }
  end

  def score
    total_weight = warn_rows.sum { |r| r.weight.to_f }
    [ 1.0 - total_weight, 0.0 ].max
  end

  def warn_reasons
    warn_rows.map { |r| "#{r.layer_key}: #{r.detail}" }
  end

  def reject_outcome
    {
      verdict: "reject",
      score: 0.0,
      reason: hard_stops.first.detail,
      reasons: hard_stops.map { |r| "#{r.layer_key}: #{r.detail}" } + warn_reasons,
      hard_stops: hard_stops.map(&:layer_key)
    }
  end

  def review_floor_outcome
    critical_reasons = errored_critical_layers.map { |r| "Could not verify #{r.layer_key}: #{r.detail}" }

    {
      verdict: "review",
      score: score,
      reason: critical_reasons.first,
      reasons: critical_reasons + warn_reasons,
      hard_stops: []
    }
  end

  def threshold_outcome
    current_score = score
    reasons = warn_reasons

    verdict =
      if current_score < thresholds["reject"]
        "reject"
      elsif current_score < thresholds["review"]
        "review"
      else
        "accept"
      end

    {
      verdict: verdict,
      score: current_score,
      reason: reasons.first,
      reasons: reasons,
      hard_stops: []
    }
  end
end
