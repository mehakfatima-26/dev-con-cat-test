require "rails_helper"

RSpec.describe Pixel do
  it "has a valid factory" do
    expect(build(:pixel)).to be_valid
  end

  it "requires a unique pixel_id" do
    create(:pixel, pixel_id: "px_dupe")
    dupe = build(:pixel, pixel_id: "px_dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:pixel_id]).to be_present
  end

  it "requires an account" do
    pixel = build(:pixel, account: nil)

    expect(pixel).not_to be_valid
  end

  it "requires name" do
    pixel = build(:pixel, name: nil)

    expect(pixel).not_to be_valid
  end

  it "exposes the statuses from the seed data" do
    expect(Pixel.statuses.keys).to contain_exactly("active", "paused")
  end

  it "rejects an empty allowed_origins list" do
    pixel = build(:pixel, allowed_origins: [])

    expect(pixel).not_to be_valid
    expect(pixel.errors[:allowed_origins]).to be_present
  end

  it "rejects a malformed origin" do
    pixel = build(:pixel, allowed_origins: [ "not a url" ])

    expect(pixel).not_to be_valid
    expect(pixel.errors[:allowed_origins]).to be_present
  end

  it "accepts multiple well-formed origins" do
    pixel = build(:pixel, allowed_origins: %w[https://example.com https://www.example.com])

    expect(pixel).to be_valid
  end

  it "prevents destroying an account that still has a pixel" do
    account = create(:account)
    create(:pixel, account: account)

    expect(account.destroy).to be false
    expect(account.errors[:base]).to be_present
  end

  it "rejects a second pixel for an account that already has one" do
    account = create(:account)
    create(:pixel, account: account)
    second = build(:pixel, account: account)

    expect(second).not_to be_valid
    expect(second.errors[:account_id]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:base_attrs) do
      {
        account_id: create(:account).id, pixel_id: "px_db_constraint_test",
        name: "DB Test", allowed_origins: "{}",
        status: 0, created_at: Time.current, updated_at: Time.current
      }
    end

    it "rejects an out-of-range status at the DB level" do
      expect {
        Pixel.insert_all!([ base_attrs.merge(status: 99) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /pixels_status_within_enum_range/)
    end

    it "rejects a duplicate pixel_id at the DB level" do
      Pixel.insert_all!([ base_attrs ])

      expect {
        Pixel.insert_all!([ base_attrs.merge(name: "Different") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a second pixel for the same account_id at the DB level" do
      Pixel.insert_all!([ base_attrs ])

      expect {
        Pixel.insert_all!([ base_attrs.merge(pixel_id: "px_db_constraint_test2") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
