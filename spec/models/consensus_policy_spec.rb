require "rails_helper"

RSpec.describe ConsensusPolicy do
  it "has a valid factory (the global default)" do
    expect(build(:consensus_policy)).to be_valid
  end

  it "is valid as a per-account override" do
    policy = build(:consensus_policy, account: create(:account))

    expect(policy).to be_valid
  end

  it "requires name" do
    policy = build(:consensus_policy, name: nil)

    expect(policy).not_to be_valid
  end

  it "rejects a second global default" do
    create(:consensus_policy, account: nil)
    dupe = build(:consensus_policy, account: nil)

    expect(dupe).not_to be_valid
    expect(dupe.errors[:account_id]).to be_present
  end

  it "rejects a second override for the same account" do
    account = create(:account)
    create(:consensus_policy, account: account)
    dupe = build(:consensus_policy, account: account)

    expect(dupe).not_to be_valid
    expect(dupe.errors[:account_id]).to be_present
  end

  it "allows a global default and a per-account override to coexist" do
    create(:consensus_policy, account: nil)
    override = build(:consensus_policy, account: create(:account))

    expect(override).to be_valid
  end

  it "rejects an active_policy_version belonging to a different policy" do
    policy = create(:consensus_policy)
    other_policy_version = create(:policy_version) # belongs to its own, different, consensus_policy
    policy.active_policy_version = other_policy_version

    expect(policy).not_to be_valid
    expect(policy.errors[:active_policy_version_id]).to be_present
  end

  it "accepts an active_policy_version belonging to itself" do
    policy = create(:consensus_policy)
    version = create(:policy_version, consensus_policy: policy)
    policy.active_policy_version = version

    expect(policy).to be_valid
  end

  it "prevents destroying an account that still has a policy override" do
    account = create(:account)
    create(:consensus_policy, account: account)

    expect(account.destroy).to be false
    expect(account.errors[:base]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    it "rejects a second global default at the DB level" do
      ConsensusPolicy.insert_all!([ { name: "Global A", created_at: Time.current, updated_at: Time.current } ])

      expect {
        ConsensusPolicy.insert_all!([ { name: "Global B", created_at: Time.current, updated_at: Time.current } ])
      }.to raise_error(ActiveRecord::RecordNotUnique, /index_consensus_policies_on_single_global_default/)
    end

    it "rejects a second override for the same account at the DB level" do
      account = create(:account)
      ConsensusPolicy.insert_all!([ { account_id: account.id, name: "Override A", created_at: Time.current, updated_at: Time.current } ])

      expect {
        ConsensusPolicy.insert_all!([ { account_id: account.id, name: "Override B", created_at: Time.current, updated_at: Time.current } ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
