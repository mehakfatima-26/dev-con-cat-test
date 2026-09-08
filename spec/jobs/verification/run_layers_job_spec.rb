require "rails_helper"

RSpec.describe Verification::RunLayersJob do
  let(:rules) do
    {
      "anura" => { "hard_stop" => { "invalid_traffic_type" => [ "bot" ] } },
      "trustedform" => { "hard_stop" => { "status" => [ "mismatch", "expired", "not_found" ] } },
      "dnc" => { "hard_stop" => { "dnc_status" => [ "dnc_listed", "internal_dnc" ] } },
      "duplicate_detection" => {
        "weighted" => { "soft_duplicate" => { "weight" => 0.05, "label" => "Soft duplicate CRM match" } }
      }
    }
  end
  let(:thresholds) { { "reject" => 0.4, "review" => 0.9 } }

  let!(:global_policy_version) do
    policy = create(:consensus_policy, account: nil, name: "Global default")
    version = create(:policy_version, consensus_policy: policy, rules: rules, thresholds: thresholds)
    policy.update!(active_policy_version: version)
    version
  end

  def account_with(modules:, allowance: 25_000)
    create(:account, enabled_modules: modules, monthly_credit_allowance: allowance)
  end

  def lead_for(account, lead_id:, phone: "+13105550142", email: "maria.gonzalez@gmail.com")
    pixel = create(:pixel, account: account)
    create(:lead, account: account, pixel: pixel, lead_id: lead_id, phone: phone, email: email)
  end

  it "runs the full pipeline for a clean lead: accept, and a CrmRecord gets created" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1001")

    run = Verification::Runner.call(lead, async: false)
    run.reload

    expect(run.status).to eq("completed")
    expect(run.accept_verdict?).to be true
    expect(run.credits_charged).to eq(5) # anura(2) + trustedform(1) + dnc(1) + duplicate_detection(1)
    expect(CrmRecord.find_by(lead: lead)).to be_present
    expect(run.certificate).to be_present
    expect(run.certificate.incomplete?).to be false
  end

  it "issues the certificate before broadcasting the final verdict, so the live activity stream can include its link" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1001")

    captured_certificate = nil
    allow(Verification::ActivityPublisher).to receive(:publish_final_verdict) do |_run, certificate|
      captured_certificate = certificate
    end

    run = Verification::Runner.call(lead, async: false)
    run.reload

    expect(captured_certificate).to be_present
    expect(captured_certificate.serial).to eq(run.certificate.serial)
  end

  it "rejects a confirmed bot outright via anura's hard stop, and still issues a certificate" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1002", phone: "+12025550188", email: "jsmith9981@mail-tempz.example")

    run = Verification::Runner.call(lead, async: false)
    run.reload

    expect(run.status).to eq("completed")
    expect(run.reject_verdict?).to be true
    expect(run.verdict_reason).to eq("Invalid traffic type: bot")
    expect(CrmRecord.find_by(lead: lead)).to be_nil
    expect(run.certificate).to be_present
    expect(run.certificate.payload["verdict"]).to eq("reject")
  end

  it "short-circuits on an exact CRM duplicate: skips every other layer, no credit charged for them" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    create(:crm_record, account: account, crm_id: "EXIST-1", phone: "+13105550142", email: "maria.gonzalez@gmail.com")
    lead = lead_for(account, lead_id: "L-1001")

    run = Verification::Runner.call(lead, async: false)
    run.reload

    expect(run.reject_verdict?).to be true
    expect(run.layer_results.find_by(layer_key: "duplicate_detection").result).to eq("fail")
    %w[anura trustedform dnc].each do |key|
      row = run.layer_results.find_by(layer_key: key)
      expect(row.state).to eq("skipped")
    end
    expect(CreditTransaction.where(verification_run: run, layer_key: %w[anura trustedform dnc])).to be_empty
    expect(run.certificate).to be_present
  end

  it "goes partial and floors the verdict at review when credits run out mid-loop, with an incomplete certificate" do
    account = account_with(modules: %w[duplicate_detection anura trustedform], allowance: 1)
    lead = lead_for(account, lead_id: "L-1001")

    run = Verification::Runner.call(lead, async: false)
    run.reload

    expect(run.status).to eq("partial")
    expect(run.review_verdict?).to be true
    expect(run.layer_results.find_by(layer_key: "duplicate_detection").state).to eq("completed")
    expect(run.layer_results.find_by(layer_key: "anura").state).to eq("errored")
    expect(run.layer_results.find_by(layer_key: "trustedform").state).to eq("errored")
    expect(CrmRecord.find_by(lead: lead)).to be_nil
    expect(run.certificate.incomplete?).to be true
    expect(run.certificate.incomplete_reason).to include("anura").and include("trustedform")
  end

  it "is retry-safe: reprocessing an already-completed run is a no-op" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1001")
    run = Verification::Runner.call(lead, async: false)
    run.reload
    charge_count = CreditTransaction.where(verification_run: run).count

    expect { described_class.new.perform(run.id) }.not_to change(Certificate, :count)
    expect(CreditTransaction.where(verification_run: run).count).to eq(charge_count)
  end

  it "self-heals: if a run finished without a certificate (e.g. a crash right after saving the verdict), a retry issues the missing one instead of skipping it forever" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1001")
    run = Verification::Runner.call(lead, async: false)
    run.reload
    original_verdict = run.verdict
    charge_count = CreditTransaction.where(verification_run: run).count

    run.certificate.delete # simulate the crash: verdict saved, certificate never made it

    described_class.new.perform(run.id)
    run.reload

    expect(run.certificate).to be_present
    expect(run.verdict).to eq(original_verdict)
    expect(CreditTransaction.where(verification_run: run).count).to eq(charge_count)
  end
end
