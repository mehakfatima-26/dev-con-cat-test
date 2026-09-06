module Layers
  class BlacklistAlliance < Base
    KEY = "blacklist_alliance"

    def call
      _field, hit = find_hard_stop
      return fail_result("Lead is #{hit}, confirmed from #{source_count} #{'source'.pluralize(source_count)}") if hit

      return pass_result("Lead is clean") if fixture["status"] == "clean"

      evaluate_weighted
    end

    private

    def evaluate_weighted
      status = fixture["status"]
      rule = rules.dig("weighted", "status", status)

      return warn_result(unrecognized(status), 0.0) unless rule

      match_confidence = (fixture["match_score"] || 100) / 100.0
      weight = rule["weight"] * match_confidence
      detail = "#{rule['label']}, confirmed from #{source_count} #{'source'.pluralize(source_count)}"

      warn_result(detail, weight)
    end

    def source_count
      fixture["sources"].to_a.size
    end
  end
end
