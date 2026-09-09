FactoryBot.define do
  factory :lead do
    sequence(:lead_id) { |n| "L-test#{n}" }
    first_name { "Jane" }
    last_name { "Doe" }
    sequence(:email) { |n| "jane.doe#{n}@example.com" }
    phone { "+13105550100" }
    ip_address { "203.0.113.99" }
    user_agent { "Mozilla/5.0 (Test Runner)" }
    landing_page_url { "https://example.com/quote" }
    campaign { "test-campaign" }
    trusted_form_cert_url { "https://cert.trustedform.example/abc123" }
    form_dwell_ms { 12_000 }
    captured_at { Time.current }
    pixel { association :pixel, strategy: :create }
    account { pixel&.account }
  end
end
