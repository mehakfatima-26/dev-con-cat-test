FactoryBot.define do
  factory :consensus_policy do
    account { nil }
    sequence(:name) { |n| "Test Policy #{n}" }
  end
end
