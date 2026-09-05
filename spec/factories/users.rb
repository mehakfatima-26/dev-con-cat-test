FactoryBot.define do
  factory :user do
    sequence(:user_id) { |n| "u_test#{n}" }
    sequence(:email) { |n| "user#{n}@testbuyer.example" }
    name { "Test User" }
    role { :member }
    account { association :account, strategy: :create }

    trait :super_admin do
      role { :super_admin }
      account { nil }
    end
  end
end
