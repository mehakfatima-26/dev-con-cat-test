require "rails_helper"

RSpec.describe Verification::Runner do
  let(:rules) do
    {
      "anura" => { "hard_stop" => { "invalid_traffic_type" => [ "bot" ] } },
      "duplicate_detection" => { "weighted" => {} }
    }
  end
  let(:thresholds) { { "reject" => 0.4, "review" => 0.9 } }

  let!(:global_policy_version) do
    policy = create(:consensus_policy, account: nil, name: "Global default")
    version = create(:policy_version, consensus_policy: policy, rules: rules, thresholds: thresholds)
    policy.update!(active_policy_version: version)
    version
  end

  def account_with(modules:, allowance:)
    create(:account, enabled_modules: modules, monthly_credit_allowance: allowance)
  end

  def lead_for(account, lead_id:, phone: "+13105550142", email: "maria.gonzalez@gmail.com")
    pixel = Pixel.find_by(account: account) || create(:pixel, account: account)
    create(:lead, account: account, pixel: pixel, lead_id: lead_id, phone: phone, email: email)
  end

  it "reserves the critical-layer cost on the run at creation time" do
    account = account_with(modules: %w[anura duplicate_detection], allowance: 10)
    lead = lead_for(account, lead_id: "L-1001")

    run = described_class.call(lead, async: true)

    expect(run.credits_reserved).to eq(3) # anura(2) + duplicate_detection(1)
    expect(run.status).to eq("pending")
  end

  it "refuses to create a run at all when the account can't afford its own critical layers" do
    account = account_with(modules: %w[anura duplicate_detection], allowance: 2)
    lead = lead_for(account, lead_id: "L-1001")

    expect(described_class.call(lead, async: true)).to be_nil
    expect(VerificationRun.where(lead: lead)).to be_empty
  end

  it "blocks a second lead's run for the same account once a first run's reservation covers the balance -- even though nothing has actually been charged yet" do
    account = account_with(modules: %w[anura duplicate_detection], allowance: 3)
    lead_a = lead_for(account, lead_id: "L-1001")
    lead_b = lead_for(account, lead_id: "L-1002", phone: "+13105550199", email: "other@gmail.com")

    run_a = described_class.call(lead_a, async: true)
    expect(run_a).to be_present
    expect(CreditTransaction.where(account: account).count).to eq(0)

    run_b = described_class.call(lead_b, async: true)

    expect(run_b).to be_nil
    expect(VerificationRun.where(lead: lead_b)).to be_empty
  end

  it "releases a run's reservation once it finishes, letting a second lead proceed" do
    account = account_with(modules: %w[anura duplicate_detection], allowance: 6)
    lead_a = lead_for(account, lead_id: "L-1001")
    lead_b = lead_for(account, lead_id: "L-1002", phone: "+13105550199", email: "other@gmail.com")

    run_a = described_class.call(lead_a, async: false)
    run_a.reload
    expect(run_a.status).to eq("completed")

    run_b = described_class.call(lead_b, async: true)

    expect(run_b).to be_present
  end
end
