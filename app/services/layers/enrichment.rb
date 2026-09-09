module Layers
  class Enrichment < Base
    KEY = "enrichment"

    SOURCE_KEYS = %w[audiencelabs bytemine].freeze

    def call
      matched = signal

      return pass_result("Both sources match: identity confirmed") if matched.empty?

      evaluate_weighted(matched)
    end

    private

    def sources
      SOURCE_KEYS.map { |key| fixture[key] }
    end

    def confirmed_sources
      sources.select { |source| source["matched"] && source["match_to_lead"] }
    end

    def weighted_rules
      rules["weighted"] || {}
    end

    def signal
      return [ "identity_mismatch" ] if sources.any? { |source| source["matched"] && !source["match_to_lead"] }
      return [ "no_enrichment_data" ] if sources.none? { |source| source["matched"] }
      return [ "single_source_match" ] if confirmed_sources.size == 1

      []
    end

    def evaluate_weighted(matched_signals)
      weight = 0.0

      descriptions = matched_signals.map do |signal_name|
        rule = weighted_rules[signal_name]

        if rule
          weight += rule["weight"]
          rule["label"]
        else
          unrecognized(signal_name)
        end
      end

      warn_result(descriptions.join("; "), weight)
    end
  end
end
