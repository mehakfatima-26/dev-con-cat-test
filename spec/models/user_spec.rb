require "rails_helper"

RSpec.describe User do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it "has a valid super_admin factory trait" do
    expect(build(:user, :super_admin)).to be_valid
  end

  it "requires a unique user_id" do
    create(:user, user_id: "u_dupe")
    dupe = build(:user, user_id: "u_dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:user_id]).to be_present
  end

  it "requires a unique email" do
    create(:user, email: "dupe@testbuyer.example")
    dupe = build(:user, email: "dupe@testbuyer.example")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:email]).to be_present
  end

  it "rejects a malformed email" do
    user = build(:user, email: "not-an-email")

    expect(user).not_to be_valid
  end

  it "requires name" do
    user = build(:user, name: nil)

    expect(user).not_to be_valid
  end

  it "exposes the roles from the seed data" do
    expect(User.roles.keys).to contain_exactly("super_admin", "account_admin", "member")
  end

  it "rejects a super_admin with an account" do
    user = build(:user, :super_admin, account: create(:account))

    expect(user).not_to be_valid
    expect(user.errors[:account_id]).to be_present
  end

  it "rejects a non-super_admin without an account" do
    user = build(:user, account: nil)

    expect(user).not_to be_valid
    expect(user.errors[:account_id]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:base_attrs) do
      {
        user_id: "u_db_constraint_test", email: "dbtest@testbuyer.example",
        name: "DB Test", role: 2, account_id: create(:account).id,
        created_at: Time.current, updated_at: Time.current
      }
    end

    it "rejects a super_admin with a non-null account_id at the DB level" do
      expect {
        User.insert_all!([ base_attrs.merge(role: 0) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /users_account_id_matches_role/)
    end

    it "rejects a non-super_admin with a null account_id at the DB level" do
      expect {
        User.insert_all!([ base_attrs.merge(account_id: nil) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /users_account_id_matches_role/)
    end

    it "rejects a duplicate user_id at the DB level" do
      User.insert_all!([ base_attrs ])

      expect {
        User.insert_all!([ base_attrs.merge(email: "different@testbuyer.example") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a duplicate email at the DB level" do
      User.insert_all!([ base_attrs ])

      expect {
        User.insert_all!([ base_attrs.merge(user_id: "u_db_constraint_test2") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
