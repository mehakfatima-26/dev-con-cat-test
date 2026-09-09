require "rails_helper"

RSpec.describe CaptureSession do
  it "has a valid factory" do
    expect(build(:capture_session)).to be_valid
  end

  it "requires a unique session_id" do
    create(:capture_session, session_id: "sess_dupe")
    dupe = build(:capture_session, session_id: "sess_dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:session_id]).to be_present
  end

  it "requires a pixel" do
    session = build(:capture_session, pixel: nil)

    expect(session).not_to be_valid
  end

  it "requires page_url" do
    session = build(:capture_session, page_url: nil)

    expect(session).not_to be_valid
  end

  it "rejects a malformed page_url" do
    session = build(:capture_session, page_url: "not a url")

    expect(session).not_to be_valid
  end

  it "allows a blank referrer (direct traffic)" do
    session = build(:capture_session, referrer: nil)

    expect(session).to be_valid
  end

  it "rejects a malformed referrer when present" do
    session = build(:capture_session, referrer: "not a url")

    expect(session).not_to be_valid
  end

  it "requires visit_ip" do
    session = build(:capture_session, visit_ip: nil)

    expect(session).not_to be_valid
  end

  it "allows a blank user_agent (itself a bot signal, not an error)" do
    session = build(:capture_session, user_agent: nil)

    expect(session).to be_valid
  end

  it "requires started_at" do
    session = build(:capture_session, started_at: nil)

    expect(session).not_to be_valid
  end

  it "rejects an account_id that doesn't match the pixel's account" do
    other_account = create(:account)
    session = build(:capture_session, account: other_account)

    expect(session).not_to be_valid
    expect(session.errors[:account_id]).to be_present
  end

  it "prevents destroying a pixel that still has capture sessions" do
    pixel = create(:pixel)
    create(:capture_session, pixel: pixel, account: pixel.account)

    expect(pixel.destroy).to be false
    expect(pixel.errors[:base]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    it "rejects a duplicate session_id at the DB level" do
      pixel = create(:pixel)
      base_attrs = {
        pixel_id: pixel.id, account_id: pixel.account_id,
        session_id: "sess_db_constraint_test", page_url: "https://example.com",
        visit_ip: "203.0.113.42", started_at: Time.current,
        created_at: Time.current, updated_at: Time.current
      }
      CaptureSession.insert_all!([ base_attrs ])

      expect {
        CaptureSession.insert_all!([ base_attrs.merge(page_url: "https://example.com/other") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a malformed visit_ip at the DB level" do
      pixel = create(:pixel)

      expect {
        CaptureSession.insert_all!([ {
          pixel_id: pixel.id, account_id: pixel.account_id,
          session_id: "sess_db_constraint_ip_test", page_url: "https://example.com",
          visit_ip: "not an ip", started_at: Time.current,
          created_at: Time.current, updated_at: Time.current
        } ])
      }.to raise_error(ActiveRecord::StatementInvalid, /invalid input syntax for type inet/)
    end
  end
end
