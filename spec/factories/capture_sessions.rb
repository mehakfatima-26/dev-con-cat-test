FactoryBot.define do
  factory :capture_session do
    sequence(:session_id) { |n| "sess_test#{n}" }
    page_url { "https://example.com/quote" }
    referrer { "https://google.com/search" }
    visit_ip { "203.0.113.42" }
    user_agent { "Mozilla/5.0 (Test Runner)" }
    started_at { Time.current }
    pixel { association :pixel, strategy: :create }
    account { pixel&.account }
  end
end
