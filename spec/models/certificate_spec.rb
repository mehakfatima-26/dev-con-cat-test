require "rails_helper"

RSpec.describe Certificate do
  it "has a valid factory" do
    expect(build(:certificate)).to be_valid
  end

  it "requires a unique serial" do
    create(:certificate, serial: "cert_dupe")
    dupe = build(:certificate, serial: "cert_dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:serial]).to be_present
  end

  it "requires payload, payload_sha256, and signature" do
    expect(build(:certificate, payload: nil)).not_to be_valid
    expect(build(:certificate, payload_sha256: nil)).not_to be_valid
    expect(build(:certificate, signature: nil)).not_to be_valid
  end

  it "requires an incomplete_reason when incomplete" do
    cert = build(:certificate, incomplete: true, incomplete_reason: nil)

    expect(cert).not_to be_valid
    expect(cert.errors[:incomplete_reason]).to be_present
  end

  it "is valid incomplete with a reason given" do
    cert = build(:certificate, incomplete: true, incomplete_reason: "Account ran out of credits mid-run")

    expect(cert).to be_valid
  end

  it "is immutable once created" do
    cert = create(:certificate)

    expect { cert.update(signature: "tampered") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "derives #lead and #account from the verification_run" do
    cert = build(:certificate)

    expect(cert.lead).to eq(cert.verification_run.lead)
    expect(cert.account).to eq(cert.verification_run.lead.account)
  end

  it "prevents destroying a verification_run that still has a certificate" do
    run = create(:verification_run, :completed)
    create(:certificate, verification_run: run)

    expect(run.destroy).to be false
    expect(run.errors[:base]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    it "rejects a second certificate for the same verification_run at the DB level" do
      run = create(:verification_run, :completed)
      base_attrs = {
        verification_run_id: run.id,
        serial: "cert_db_constraint_test", payload: { "x" => 1 }.to_json,
        payload_sha256: "a" * 64, signature: "sig", issued_at: Time.current,
        created_at: Time.current, updated_at: Time.current
      }
      Certificate.insert_all!([ base_attrs ])

      expect {
        Certificate.insert_all!([ base_attrs.merge(serial: "cert_db_constraint_test2") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
