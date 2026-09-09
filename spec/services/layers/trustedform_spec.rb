require "rails_helper"

RSpec.describe Layers::Trustedform do
  let(:rules) { { "hard_stop" => { "status" => [ "mismatch", "expired", "not_found" ] } } }

  it "passes a verified certificate (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:detail]).to eq("Consent certificate verified, phone and email match")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "hard-stops a mismatched/expired certificate (L-1010)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1010"), rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("Consent certificate status: mismatch")
    expect(outcome[:weight]).to be_nil
    expect(outcome[:raw]["matches_phone"]).to eq(false)
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
