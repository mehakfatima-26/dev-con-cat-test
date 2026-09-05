FactoryBot.define do
  factory :pixel do
    sequence(:pixel_id) { |n| "px_test#{n}" }
    name { "Test Landing Page" }
    signing_secret { SecureRandom.hex(20) }
    allowed_origins { %w[https://example.com] }
    status { :active }
    account { association :account, strategy: :create }
  end
end
