FactoryBot.define do
  factory :pixel do
    sequence(:pixel_id) { |n| "px_test#{n}" }
    name { "Test Landing Page" }
    allowed_origins { %w[https://example.com] }
    status { :active }
    account { association :account, strategy: :create }
  end
end
