require "rails_helper"

RSpec.describe VerificationRun do
  it "has a valid factory (pending)" do
    expect(build(:verification_run)).to be_valid
  end

  it "has a valid factory (completed)" do
    expect(build(:verification_run, :completed)).to be_valid
  end

  it "requires started_at" do
    expect(build(:verification_run, started_at: nil)).not_to be_valid
  end

  it "rejects a negative credits_charged" do
    expect(build(:verification_run, credits_charged: -1)).not_to be_valid
  end

  it "accepts an account-scoped policy_version that matches the run's own lead's account" do
    account = create(:account)
    lead = create(:lead, pixel: create(:pixel, account: account), account: account)
    policy = create(:consensus_policy, account: account)
    version = create(:policy_version, consensus_policy: policy)

    run = build(:verification_run, lead: lead, policy_version: version)

    expect(run).to be_valid
  end

  it "rejects a policy_version belonging to a different account's override" do
    lead = create(:lead)
    other_account = create(:account)
    other_policy = create(:consensus_policy, account: other_account)
    version = create(:policy_version, consensus_policy: other_policy)

    run = build(:verification_run, lead: lead, policy_version: version)

    expect(run).not_to be_valid
    expect(run.errors[:policy_version_id]).to be_present
  end

  it "derives #account from the lead, with no denormalized column of its own" do
    run = build(:verification_run)

    expect(run.account).to eq(run.lead.account)
  end

  describe "verdict/status consistency" do
    it "rejects a pending run with a verdict already set" do
      run = build(:verification_run, status: :pending, verdict: :accept)

      expect(run).not_to be_valid
      expect(run.errors[:verdict]).to be_present
    end

    it "rejects a completed run with no verdict" do
      run = build(:verification_run, status: :completed, verdict: nil)

      expect(run).not_to be_valid
      expect(run.errors[:verdict]).to be_present
    end

    it "allows a partial run with a verdict set" do
      run = build(:verification_run, :completed, status: :partial)

      expect(run).to be_valid
    end
  end

  describe "enabled_modules_snapshot validation" do
    it "rejects an unknown module" do
      run = build(:verification_run, enabled_modules_snapshot: %w[vpn_proxy not_a_real_layer])

      expect(run).not_to be_valid
      expect(run.errors[:enabled_modules_snapshot]).to be_present
    end

    it "accepts every known layer key" do
      expect(build(:verification_run, enabled_modules_snapshot: DetectionLayer::KEYS)).to be_valid
    end
  end

  it "prevents destroying a lead that still has a verification run" do
    lead = create(:lead)
    create(:verification_run, lead: lead)

    expect(lead.destroy).to be false
    expect(lead.errors[:base]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:lead) { create(:lead) }
    let(:policy_version) { create(:policy_version, consensus_policy: create(:consensus_policy, account: nil)) }
    let(:base_attrs) do
      {
        lead_id: lead.id, policy_version_id: policy_version.id,
        status: 0, credits_charged: 0, started_at: Time.current,
        created_at: Time.current, updated_at: Time.current
      }
    end

    it "rejects a negative credits_charged at the DB level" do
      expect {
        VerificationRun.insert_all!([ base_attrs.merge(credits_charged: -5) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /verification_runs_credits_charged_non_negative/)
    end

    it "rejects a pending run with a verdict set at the DB level" do
      expect {
        VerificationRun.insert_all!([ base_attrs.merge(status: 0, verdict: 0) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /verification_runs_verdict_matches_status/)
    end

    it "rejects a completed run with no verdict at the DB level" do
      expect {
        VerificationRun.insert_all!([ base_attrs.merge(status: 2, verdict: nil) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /verification_runs_verdict_matches_status/)
    end

    it "rejects a second run for the same lead at the DB level" do
      VerificationRun.insert_all!([ base_attrs ])

      expect {
        VerificationRun.insert_all!([ base_attrs ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
