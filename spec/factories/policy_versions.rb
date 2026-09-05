FactoryBot.define do
  factory :policy_version do
    consensus_policy { create(:consensus_policy, account: create(:account)) }
    sequence(:version)
    rules do
      {
        "exact_duplicate" => { "type" => "hard_stop", "label" => "Exact CRM duplicate", "enabled" => true },
        "suspected_litigator" => { "type" => "hard_stop", "label" => "Known TCPA litigator", "enabled" => true },
        "vpn_detected" => { "type" => "weighted", "weight" => 0.3, "label" => "VPN/proxy traffic", "enabled" => true },
        "invalid_email" => { "type" => "weighted", "weight" => 0.2, "label" => "Undeliverable email", "enabled" => true }
      }
    end
    thresholds { { "reject" => 0.4, "review" => 0.75 } }
    notes { "Test policy version" }
  end
end
