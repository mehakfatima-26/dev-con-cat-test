FactoryBot.define do
  factory :credit_transaction do
    account { association :account, strategy: :create }
    amount { -2 }
    layer_key { "anura" }
    verification_run { association :verification_run, strategy: :create }
    sequence(:idempotency_key) { |n| "idem_test#{n}" }
  end
end
