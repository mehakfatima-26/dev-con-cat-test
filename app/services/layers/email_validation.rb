module Layers
  class EmailValidation < Base
    KEY = "email_validation"

    def call
      matched = deliverable_matches + disposable_matches
      return pass_result("Both providers agree: deliverable, not disposable") if matched.empty?

      evaluate_weighted(matched)
    end

    private

    def zerobounce
      fixture.dig("providers", "zerobounce")
    end

    def neverbounce
      fixture.dig("providers", "neverbounce")
    end

    def weighted_rules
      rules["weighted"] || {}
    end

    def deliverable_matches
      values = [ zerobounce["deliverable"], neverbounce["deliverable"] ]

      if values.all? { |value| value == false }
        [ "both_undeliverable" ]
      elsif values.uniq.size > 1
        [ "deliverable_disagreement" ]
      else
        []
      end
    end

    def disposable_matches
      values = [ zerobounce["disposable"], neverbounce["disposable"] ]

      if values.all? { |value| value == true }
        [ "both_disposable" ]
      elsif values.uniq.size > 1
        [ "disposable_disagreement" ]
      else
        []
      end
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
