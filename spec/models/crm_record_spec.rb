require "rails_helper"

RSpec.describe CrmRecord do
  it "has a valid factory (imported)" do
    expect(build(:crm_record)).to be_valid
  end

  it "is valid with a lead attached (accepted lead)" do
    account = create(:account)
    lead = create(:lead, pixel: create(:pixel, account: account), account: account)
    record = build(:crm_record, account: account, lead: lead)

    expect(record).to be_valid
  end

  it "requires a unique crm_id within the same account" do
    account = create(:account)
    create(:crm_record, account: account, crm_id: "CRM-dupe")
    dupe = build(:crm_record, account: account, crm_id: "CRM-dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:crm_id]).to be_present
  end

  it "allows the same crm_id across different accounts" do
    create(:crm_record, crm_id: "CRM-shared")

    expect(build(:crm_record, crm_id: "CRM-shared")).to be_valid
  end

  it "rejects a malformed email" do
    expect(build(:crm_record, email: "not-an-email")).not_to be_valid
  end

  it "rejects a malformed phone" do
    expect(build(:crm_record, phone: "call-me")).not_to be_valid
  end

  it "requires crm_created_at" do
    expect(build(:crm_record, crm_created_at: nil)).not_to be_valid
  end

  it "rejects a lead belonging to a different account" do
    other_account = create(:account)
    lead = create(:lead)

    record = build(:crm_record, account: other_account, lead: lead)

    expect(record).not_to be_valid
    expect(record.errors[:lead_id]).to be_present
  end

  it "rejects a second crm_record for the same lead" do
    account = create(:account)
    lead = create(:lead, pixel: create(:pixel, account: account), account: account)
    create(:crm_record, account: account, lead: lead)
    dupe = build(:crm_record, account: account, lead: lead)

    expect(dupe).not_to be_valid
  end

  describe "database-level constraints (bypassing model validations)" do
    it "rejects a duplicate [account_id, crm_id] at the DB level" do
      account = create(:account)
      base_attrs = {
        account_id: account.id, crm_id: "CRM-db-test", first_name: "DB", last_name: "Test",
        email: "db@example.com", phone: "+13105550100", crm_created_at: Time.current,
        created_at: Time.current, updated_at: Time.current
      }
      CrmRecord.insert_all!([ base_attrs ])

      expect {
        CrmRecord.insert_all!([ base_attrs.merge(email: "different@example.com") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a second crm_record for the same lead_id at the DB level" do
      account = create(:account)
      lead = create(:lead, pixel: create(:pixel, account: account), account: account)
      base_attrs = {
        account_id: account.id, lead_id: lead.id, crm_id: "CRM-db-test2",
        first_name: "DB", last_name: "Test", email: "db2@example.com", phone: "+13105550100",
        crm_created_at: Time.current, created_at: Time.current, updated_at: Time.current
      }
      CrmRecord.insert_all!([ base_attrs ])

      expect {
        CrmRecord.insert_all!([ base_attrs.merge(crm_id: "CRM-db-test3") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
