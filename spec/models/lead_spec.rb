require "rails_helper"

RSpec.describe Lead do
  it "has a valid factory" do
    expect(build(:lead)).to be_valid
  end

  it "is valid without a capture_session (the 12 seeded leads have none)" do
    lead = build(:lead, capture_session: nil)

    expect(lead).to be_valid
  end

  it "requires a unique lead_id" do
    create(:lead, lead_id: "L-dupe")
    dupe = build(:lead, lead_id: "L-dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:lead_id]).to be_present
  end

  it "requires first_name and last_name" do
    expect(build(:lead, first_name: nil)).not_to be_valid
    expect(build(:lead, last_name: nil)).not_to be_valid
  end

  it "rejects a malformed email" do
    expect(build(:lead, email: "not-an-email")).not_to be_valid
  end

  it "rejects a malformed phone" do
    expect(build(:lead, phone: "call-me-maybe")).not_to be_valid
  end

  it "accepts the seed data's E.164 phone format" do
    expect(build(:lead, phone: "+13105550142")).to be_valid
  end

  it "requires ip_address" do
    expect(build(:lead, ip_address: nil)).not_to be_valid
  end

  it "allows a blank user_agent (itself a bot signal, not an error)" do
    expect(build(:lead, user_agent: nil)).to be_valid
  end

  it "allows a blank campaign (organic traffic has no attribution)" do
    expect(build(:lead, campaign: nil)).to be_valid
  end

  it "allows a blank trusted_form_cert_url (no retained consent is a real, meaningful case)" do
    expect(build(:lead, trusted_form_cert_url: nil)).to be_valid
  end

  it "rejects a malformed trusted_form_cert_url when present" do
    expect(build(:lead, trusted_form_cert_url: "not a url")).not_to be_valid
  end

  it "rejects a negative form_dwell_ms" do
    expect(build(:lead, form_dwell_ms: -1)).not_to be_valid
  end

  it "rejects an account_id that doesn't match the pixel's account" do
    other_account = create(:account)
    lead = build(:lead, account: other_account)

    expect(lead).not_to be_valid
    expect(lead.errors[:account_id]).to be_present
  end

  it "rejects a capture_session belonging to a different pixel" do
    pixel = create(:pixel)
    other_session = create(:capture_session) # different pixel/account entirely
    lead = build(:lead, pixel: pixel, account: pixel.account, capture_session: other_session)

    expect(lead).not_to be_valid
    expect(lead.errors[:capture_session_id]).to be_present
  end

  it "prevents destroying a pixel that still has leads" do
    pixel = create(:pixel)
    create(:lead, pixel: pixel, account: pixel.account)

    expect(pixel.destroy).to be false
    expect(pixel.errors[:base]).to be_present
  end

  it "reaches its certificate in one hop, with no stored lead_id on Certificate" do
    lead = create(:lead)
    run = create(:verification_run, :completed, lead: lead)
    cert = create(:certificate, verification_run: run)

    expect(lead.certificate).to eq(cert)
  end

  it "has no certificate when none has been issued yet" do
    lead = create(:lead)

    expect(lead.certificate).to be_nil
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:pixel) { create(:pixel) }
    let(:base_attrs) do
      {
        account_id: pixel.account_id, pixel_id: pixel.id,
        lead_id: "L-db_constraint_test", first_name: "DB", last_name: "Test",
        email: "db@example.com", phone: "+13105550100", ip_address: "203.0.113.99",
        landing_page_url: "https://example.com", form_dwell_ms: 1000,
        captured_at: Time.current, created_at: Time.current, updated_at: Time.current
      }
    end

    it "rejects a negative form_dwell_ms at the DB level" do
      expect {
        Lead.insert_all!([ base_attrs.merge(form_dwell_ms: -500) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /leads_form_dwell_ms_non_negative/)
    end

    it "rejects a duplicate lead_id at the DB level" do
      Lead.insert_all!([ base_attrs ])

      expect {
        Lead.insert_all!([ base_attrs.merge(email: "different@example.com") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects two leads sharing a capture_session_id at the DB level" do
      session = create(:capture_session, pixel: pixel, account: pixel.account)
      Lead.insert_all!([ base_attrs.merge(capture_session_id: session.id) ])

      expect {
        Lead.insert_all!([ base_attrs.merge(lead_id: "L-db_constraint_test2", capture_session_id: session.id) ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
