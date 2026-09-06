FactoryBot.define do
  factory :policy_version do
    consensus_policy { create(:consensus_policy, account: create(:account)) }
    sequence(:version)
    enabled_modules { %w[vpn_proxy anura duplicate_detection email_validation blacklist_alliance] }
    rules do
      {
        "duplicate_detection" => {
          "exact_duplicate" => { "type" => "hard_stop", "label" => "Exact CRM duplicate", "enabled" => true }
        },
        "blacklist_alliance" => {
          "confirmed_litigator" => { "type" => "hard_stop", "label" => "Known TCPA litigator", "enabled" => true }
        },
        "vpn_proxy" => {
          "vpn_detected" => { "type" => "weighted", "weight" => 0.3, "label" => "VPN/proxy traffic", "enabled" => true }
        },
        "email_validation" => {
          "invalid_email" => { "type" => "weighted", "weight" => 0.2, "label" => "Undeliverable email", "enabled" => true }
        }
      }
    end
    thresholds { { "reject" => 0.4, "review" => 0.75 } }
    notes { "Test policy version" }
  end
end
