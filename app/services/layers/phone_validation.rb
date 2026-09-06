module Layers
  class PhoneValidation < Base
    KEY = "phone_validation"

    PROVIDER_KEYS = %w[twilio_lookup numverify telesign].freeze

    def call
      matched = validity_matches + line_type_matches
      return pass_result("All providers agree: valid, consistent line type") if matched.empty?

      evaluate_weighted(matched)
    end

    private

    def providers
      PROVIDER_KEYS.map { |key| fixture.dig("providers", key) }
    end

    def valid_providers
      providers.select { |provider| provider["valid"] }
    end

    def valid_line_types
      valid_providers.map { |provider| provider["line_type"] }.uniq
    end

    def weighted_rules
      rules["weighted"] || {}
    end

    def validity_matches
      return [ "all_invalid" ] if valid_providers.empty?
      return [] if valid_providers.size == providers.size # unanimous valid
      return [] if valid_providers.size >= 2 && valid_line_types.size == 1 # forgiven

      [ "validity_disagreement" ]
    end

    def line_type_matches
      return [] if valid_providers.size < 2

      return [ "line_type_disagreement" ] if valid_line_types.size > 1

      valid_line_types.first == "voip" ? [ "all_voip" ] : []
    end

    def evaluate_weighted(matched_signals)
      weight = 0.0

      descriptions = matched_signals.map do |signal|
        rule = weighted_rules[signal]

        if rule
          weight += rule["weight"]
          rule["label"]
        else
          unrecognized(signal)
        end
      end

      warn_result(descriptions.join("; "), weight)
    end
  end
end
