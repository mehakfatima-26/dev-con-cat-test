require "rails_helper"

RSpec.describe Layers::DuplicateDetection do
  let(:rules) { { "weighted" => { "soft_duplicate" => { "weight" => 0.15, "label" => "Soft duplicate: phone or email matches an existing CRM record" } } } }

  def lead_for(account, phone:, email:)
    pixel = create(:pixel, account: account)
    create(:lead, account: account, pixel: pixel, phone: phone, email: email)
  end

  it "passes when nothing in the account's CRM matches" do
    account = create(:account)
    create(:crm_record, account: account, phone: "+13105550999", email: "other@example.com")
    lead = lead_for(account, phone: "+13105550100", email: "new@example.com")

    outcome = described_class.new(lead, rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "hard-stops an exact duplicate (same phone AND email), unconditionally regardless of rules" do
    account = create(:account)
    create(:crm_record, account: account, crm_id: "ME-88213", phone: "+17135550173", email: "patricia.nguyen@gmail.com")
    lead = lead_for(account, phone: "+17135550173", email: "patricia.nguyen@gmail.com")

    outcome = described_class.new(lead, {}).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("Exact duplicate of existing CRM record ME-88213")
    expect(outcome[:weight]).to be_nil
    expect(outcome[:raw]["matched_field"]).to eq("phone and email")
  end

  it "weights a soft duplicate (same phone, different email) rather than hard-stopping it" do
    account = create(:account)
    create(:crm_record, account: account, crm_id: "AI-55019", phone: "+16465550193", email: "emily.watson.personal@gmail.com")
    lead = lead_for(account, phone: "+16465550193", email: "emily.new@example.com")

    outcome = described_class.new(lead, rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to include("AI-55019")
    expect(outcome[:detail]).to include("matched on phone")
    expect(outcome[:weight]).to eq(0.15)
  end

  it "weights a soft duplicate matched on email alone (different phone, same email)" do
    account = create(:account)
    create(:crm_record, account: account, crm_id: "CRM-email-match", phone: "+13105550999", email: "shared@example.com")
    lead = lead_for(account, phone: "+13105550100", email: "shared@example.com")

    outcome = described_class.new(lead, rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to include("matched on email")
  end

  it "ignores a matching phone+email in a different account (tenant-scoped)" do
    other_account = create(:account)
    create(:crm_record, account: other_account, phone: "+13105550100", email: "cross-tenant@example.com")
    account = create(:account)
    lead = lead_for(account, phone: "+13105550100", email: "cross-tenant@example.com")

    outcome = described_class.new(lead, rules).call

    expect(outcome[:result]).to eq("pass")
  end
end
