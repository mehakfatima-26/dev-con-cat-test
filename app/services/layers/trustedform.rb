module Layers
  class Trustedform < Base
    KEY = "trustedform"

    def call
      _field, hit = find_hard_stop
      return fail_result("Consent certificate status: #{hit}") if hit

      return pass_result(verified_detail) if fixture["status"] == "verified"

      warn_result(unrecognized(fixture["status"]), 0.0)
    end

    private

    def verified_detail
      detail = "Consent certificate verified"
      detail += ", phone and email match" if fixture["matches_phone"] && fixture["matches_email"]
      detail
    end
  end
end
