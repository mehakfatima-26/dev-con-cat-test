module Layers
  class Voice < Base
    KEY = "voice"

    def call
      return not_applicable_result("No voice sample captured for this lead") unless fixture["has_sample"]

      _field, hit = find_hard_stop
      return fail_result("Voice verdict: #{hit}") if hit

      pass_result("Voice verdict: unique human voice, no reuse detected")
    end
  end
end
