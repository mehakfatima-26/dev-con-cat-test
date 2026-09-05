FactoryBot.define do
  factory :certificate do
    verification_run { association :verification_run, :completed, strategy: :create }
    sequence(:serial) { |n| "cert_test#{n}" }
    payload { { "verdict" => "accept", "score" => 0.95 } }
    payload_sha256 { "a" * 64 }
    signature { "sig_test" }
    issued_at { Time.current }
  end
end
