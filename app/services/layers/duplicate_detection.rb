module Layers
  class DuplicateDetection < Base
    KEY = "duplicate_detection"

    def self.exact_match(account:, phone:, email:)
      account.crm_records.find_by(phone: phone, email: email)
    end

    def call
      return fail_result("Exact duplicate of existing CRM record #{exact_match.crm_id}") if exact_match

      return pass_result("No matching CRM record found") unless soft_match

      rule = rules.dig("weighted", "soft_duplicate")
      weight = rule ? rule["weight"] : 0.0
      label = rule ? rule["label"] : unrecognized("soft_duplicate")

      warn_result("#{label} (CRM record #{soft_match.crm_id}, matched on #{matched_field})", weight)
    end

    private

    def matching_records
      @matching_records ||= lead.account.crm_records
        .where("phone = :phone OR email = :email", phone: lead.phone, email: lead.email)
        .to_a
    end

    def exact_match
      @exact_match ||= matching_records.find { |record| record.phone == lead.phone && record.email == lead.email }
    end

    def soft_match
      @soft_match ||= matching_records.first
    end

    def matched_field
      soft_match.phone == lead.phone ? "phone" : "email"
    end

    def fixture
      @fixture ||= {
        "matched_crm_id" => (exact_match || soft_match)&.crm_id,
        "matched_field" => exact_match ? "phone and email" : (soft_match && matched_field),
        "matched_crm_created_at" => (exact_match || soft_match)&.crm_created_at&.iso8601
      }
    end
  end
end
