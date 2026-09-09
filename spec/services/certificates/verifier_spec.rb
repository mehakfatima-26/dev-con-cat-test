require "rails_helper"

RSpec.describe Certificates::Verifier do
  def issue_certificate_for(account)
    pixel = account.pixel || create(:pixel, account: account)
    lead = create(:lead, account: account, pixel: pixel)
    run = create(:verification_run, :completed, lead: lead)
    create(:layer_result, verification_run: run)
    Certificates::Issuer.call(run)
  end

  it "is fully valid right after being issued, untouched" do
    cert = issue_certificate_for(create(:account))

    result = described_class.call(cert)

    expect(result).to eq(valid: true, payload_valid: true, signature_valid: true, chain_valid: true)
  end

  it "catches a payload edited without updating its fingerprint" do
    cert = issue_certificate_for(create(:account))
    Certificate.where(id: cert.id).update_all(payload: cert.payload.merge("verdict" => "reject"))

    result = described_class.call(Certificate.find(cert.id))

    expect(result[:payload_valid]).to be false
    expect(result[:valid]).to be false
  end

  it "catches a payload forged together with a matching fingerprint, since the signature can't be forged without the secret" do
    cert = issue_certificate_for(create(:account))
    forged_payload = cert.payload.merge("verdict" => "reject", "score" => 0.0)
    forged_hash = Digest::SHA256.hexdigest(Certificate.canonical_json(forged_payload))
    Certificate.where(id: cert.id).update_all(payload: forged_payload, payload_sha256: forged_hash)

    result = described_class.call(Certificate.find(cert.id))

    expect(result[:payload_valid]).to be true # they got the fingerprint right...
    expect(result[:signature_valid]).to be false # ...but not the signature
    expect(result[:valid]).to be false
  end

  it "catches a signature edited directly" do
    cert = issue_certificate_for(create(:account))
    Certificate.where(id: cert.id).update_all(signature: "0" * 64)

    result = described_class.call(Certificate.find(cert.id))

    expect(result[:signature_valid]).to be false
    expect(result[:valid]).to be false
  end

  it "is valid for the first certificate of an account, which has no previous link" do
    cert = issue_certificate_for(create(:account))

    expect(described_class.call(cert)[:chain_valid]).to be true
    expect(cert.prev_sha256).to be_nil
  end

  it "catches a broken chain link on the second certificate for an account" do
    account = create(:account)
    issue_certificate_for(account)
    second_cert = issue_certificate_for(account)
    Certificate.where(id: second_cert.id).update_all(prev_sha256: "f" * 64)

    result = described_class.call(Certificate.find(second_cert.id))

    expect(result[:chain_valid]).to be false
    expect(result[:valid]).to be false
  end

  it "catches a chain link that was cleared to hide that an earlier certificate exists" do
    account = create(:account)
    issue_certificate_for(account)
    second_cert = issue_certificate_for(account)
    Certificate.where(id: second_cert.id).update_all(prev_sha256: nil)

    result = described_class.call(Certificate.find(second_cert.id))

    expect(result[:chain_valid]).to be false
  end
end
