FactoryBot.define do
  factory :crm_record do
    account { association :account, strategy: :create }
    sequence(:crm_id) { |n| "CRM-test#{n}" }
    first_name { "Jane" }
    last_name { "Doe" }
    sequence(:email) { |n| "jane.crm#{n}@example.com" }
    phone { "+13105550100" }
    crm_created_at { 1.year.ago }
    lead { nil }
  end
end
