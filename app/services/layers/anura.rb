module Layers
  class Anura < Base
    KEY = "anura"

    def call
      field, hit = find_hard_stop
      return fail_result("#{field.humanize}: #{hit}") if hit

      return pass_result("Anura: result is good, no fraud signals") if fixture["result"] == "good"

      evaluate_weighted
    end

    private

    def evaluate_weighted
      weighted_rule_ids = rules.dig("weighted", "rule_ids") || {}
      confidence = fixture["confidence"] || 1.0
      weight = 0.0

      descriptions = fixture["rule_ids"].to_a.map do |raw_id|
        id = raw_id.downcase
        rule = weighted_rule_ids[id]

        if rule
          weight += rule["weight"] * confidence
          rule["label"]
        else
          unrecognized(id)
        end
      end

      descriptions = [ "Anura result: #{fixture['result']}, no configured signal explains it" ] if descriptions.empty?

      warn_result(descriptions.join("; "), [ weight, max_weight ].min)
    end

    def max_weight
      rules["max_weight"] || Float::INFINITY
    end
  end
end
