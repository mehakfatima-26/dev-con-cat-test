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
  end

  it "rejects a confirmed bot outright via anura's hard stop" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1002", phone: "+12025550188", email: "jsmith9981@mail-tempz.example")

    run = Verification::Runner.call(lead, async: false)
    run.reload

    expect(run.status).to eq("completed")
    expect(run.reject_verdict?).to be true
    expect(run.verdict_reason).to eq("Invalid traffic type: bot")
    expect(CrmRecord.find_by(lead: lead)).to be_nil
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
  end

  it "goes partial and floors the verdict at review when credits run out mid-loop" do
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
  end

  it "is retry-safe: reprocessing an already-completed run is a no-op" do
    account = account_with(modules: %w[anura trustedform dnc duplicate_detection])
    lead = lead_for(account, lead_id: "L-1001")
    run = Verification::Runner.call(lead, async: false)
    run.reload
    charge_count = CreditTransaction.where(verification_run: run).count

    described_class.new.perform(run.id)

    expect(CreditTransaction.where(verification_run: run).count).to eq(charge_count)
  end
end
