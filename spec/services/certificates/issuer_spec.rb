require "rails_helper"

RSpec.describe Certificates::Issuer do
  def run_for(account, verdict: :accept, status: :completed, score: 0.95)
    pixel = account.pixel || create(:pixel, account: account)
    lead = create(:lead, account: account, pixel: pixel)
    run = create(:verification_run, :completed, lead: lead, verdict: verdict, status: status, score: score)
    create(:layer_result, verification_run: run, layer_key: "vpn_proxy", state: :completed, result: :pass)
    run
  end

  it "creates exactly one certificate for the run" do
    run = run_for(create(:account))

    expect { described_class.call(run) }.to change(Certificate, :count).by(1)
    expect(run.reload.certificate).to be_present
  end

  it "captures what a buyer would need to defend the lead later" do
    run = run_for(create(:account), verdict: :reject)
    cert = described_class.call(run)

    expect(cert.payload["lead_id"]).to eq(run.lead.lead_id)
    expect(cert.payload["account_id"]).to eq(run.lead.account.account_id)
    expect(cert.payload["verdict"]).to eq("reject")
    expect(cert.payload["score"]).to eq(run.score.to_f)
    expect(cert.payload["reasons"]).to eq(run.reasons)
    expect(cert.payload["trusted_form_cert_url"]).to eq(run.lead.trusted_form_cert_url)
    expect(cert.payload["landing_page_url"]).to eq(run.lead.landing_page_url)
    expect(cert.payload["captured_at"]).to eq(run.lead.captured_at.iso8601)
    expect(cert.payload["credits_charged"]).to eq(run.credits_charged)
    expect(cert.payload["layers"]).to include(a_hash_including("layer_key" => "vpn_proxy", "result" => "pass"))
    expect(cert.payload["policy_version"]).to eq(
      "consensus_policy" => run.policy_version.consensus_policy.name,
      "version" => run.policy_version.version
    )
  end

  it "lists every layer the account never enabled, so a reader with no database access can't confuse that with a missing/unexplained layer" do
    account = create(:account)
    pixel = create(:pixel, account: account)
    lead = create(:lead, account: account, pixel: pixel)
    run = create(:verification_run, :completed, lead: lead, enabled_modules_snapshot: %w[anura trustedform])
    create(:layer_result, verification_run: run, layer_key: "anura")

    cert = described_class.call(run)

    expect(cert.payload["not_enabled_layers"]).to match_array(DetectionLayer::KEYS - %w[anura trustedform])
    expect(cert.payload["not_enabled_layers"]).not_to include("anura", "trustedform")
  end

  it "issues a certificate for a REJECT the same as an ACCEPT -- every processed lead gets one" do
    run = run_for(create(:account), verdict: :reject)

    expect(described_class.call(run)).to be_persisted
  end

  it "stores a fingerprint that still matches after a real database round-trip" do
    run = run_for(create(:account))
    cert = described_class.call(run)

    reloaded = Certificate.find(cert.id)
    recomputed = Digest::SHA256.hexdigest(Certificate.canonical_json(reloaded.payload))

    expect(recomputed).to eq(cert.payload_sha256)
  end

  it "produces a signature that verifies against the stored hashes" do
    run = run_for(create(:account))
    cert = described_class.call(run)

    expected = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{cert.payload_sha256}:#{cert.prev_sha256}")

    expect(cert.signature).to eq(expected)
  end

  it "leaves the first certificate for an account with no previous link" do
    run = run_for(create(:account))
    cert = described_class.call(run)

    expect(cert.prev_sha256).to be_nil
  end

  it "chains a second certificate for the same account to the first one's fingerprint" do
    account = create(:account)
    first_cert = described_class.call(run_for(account))
    second_cert = described_class.call(run_for(account))

    expect(second_cert.prev_sha256).to eq(first_cert.payload_sha256)
  end

  it "does not chain certificates across different accounts" do
    described_class.call(run_for(create(:account)))
    other_account_cert = described_class.call(run_for(create(:account)))

    expect(other_account_cert.prev_sha256).to be_nil
  end

  it "marks a partial (credit-starved) run's certificate incomplete, naming the skipped layers" do
    run = run_for(create(:account), status: :partial, verdict: :review, score: 0.5)
    create(:layer_result, verification_run: run, layer_key: "anura", state: :errored,
      detail: "anura not run: insufficient credits", result: nil, weight: nil)

    cert = described_class.call(run)

    expect(cert.incomplete?).to be true
    expect(cert.incomplete_reason).to include("anura")
  end

  it "does not mark a normally completed run's certificate incomplete" do
    run = run_for(create(:account), status: :completed)
    cert = described_class.call(run)

    expect(cert.incomplete?).to be false
    expect(cert.incomplete_reason).to be_nil
  end
end
