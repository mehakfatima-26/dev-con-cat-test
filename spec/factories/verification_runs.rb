FactoryBot.define do
  factory :verification_run do
    lead { association :lead, strategy: :create }

    policy_version { create(:policy_version, consensus_policy: ConsensusPolicy.find_by(account: nil) || create(:consensus_policy, account: nil)) }
    status { :pending }
    started_at { Time.current }
    enabled_modules_snapshot { DetectionLayer::KEYS }

    trait :completed do
      status { :completed }
      verdict { :accept }
      verdict_reason { "All layers passed" }
      score { 0.95 }
      finished_at { Time.current }
    end
  end
end
