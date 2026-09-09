require "rails_helper"

RSpec.describe PolicyVersion do
  it "has a valid factory" do
    expect(build(:policy_version)).to be_valid
  end

  it "requires a positive integer version" do
    expect(build(:policy_version, version: 0)).not_to be_valid
    expect(build(:policy_version, version: -1)).not_to be_valid
    expect(build(:policy_version, version: 1.5)).not_to be_valid
  end

  it "requires a unique version within the same policy" do
    policy = create(:consensus_policy, account: create(:account))
    create(:policy_version, consensus_policy: policy, version: 1)
    dupe = build(:policy_version, consensus_policy: policy, version: 1)

    expect(dupe).not_to be_valid
    expect(dupe.errors[:version]).to be_present
  end

  it "allows the same version number across different policies" do
    version_a = create(:policy_version, version: 1)
    version_b = build(:policy_version, version: 1)

    expect(version_a.consensus_policy_id).not_to eq(version_b.consensus_policy_id)
    expect(version_b).to be_valid
  end

  it "is immutable once created" do
    version = create(:policy_version)

    expect { version.update(notes: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "prevents destroying a consensus_policy that still has versions" do
    policy = create(:consensus_policy, account: create(:account))
    create(:policy_version, consensus_policy: policy)

    expect(policy.destroy).to be false
    expect(policy.errors[:base]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:policy) { create(:consensus_policy, account: create(:account)) }
    let(:base_attrs) do
      {
        consensus_policy_id: policy.id, version: 1,
        rules: { "x" => { "type" => "hard_stop" } }.to_json, thresholds: { "reject" => 0.4, "review" => 0.7 }.to_json,
        created_at: Time.current, updated_at: Time.current
      }
    end

    it "rejects a non-positive version at the DB level" do
      expect {
        PolicyVersion.insert_all!([ base_attrs.merge(version: 0) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /policy_versions_version_positive/)
    end

    it "rejects a duplicate [consensus_policy_id, version] at the DB level" do
      PolicyVersion.insert_all!([ base_attrs ])

      expect {
        PolicyVersion.insert_all!([ base_attrs ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
