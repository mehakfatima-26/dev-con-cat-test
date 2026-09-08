FactoryBot.define do
  factory :account do
    sequence(:account_id) { |n| "acct_test#{n}" }
    company_name { "Test Buyer Co." }
    plan { :growth }
    status { :active }
    monthly_credit_allowance { 25_000 }
    cycle_start { Date.current.beginning_of_month }
    cycle_end { Date.current.end_of_month }
    enabled_modules { %w[anura trustedform dnc phone_validation duplicate_detection] }
    billing_contact { "ops@testbuyer.example" }
  end
end
