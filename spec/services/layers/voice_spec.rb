require "rails_helper"

RSpec.describe Layers::Voice do
  let(:rules) { { "hard_stop" => { "verdict" => [ "human_reused_actor", "synthetic" ] } } }

  it "is not_applicable when no voice sample was captured (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:not_applicable]).to be true
    expect(outcome[:result]).to be_nil
    expect(outcome[:weight]).to be_nil
  end

  it "passes a unique human voice (L-1006)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1006"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:not_applicable]).to be_falsy
  end

  it "hard-stops a reused voice-actor (L-1009)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1009"), rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("Voice verdict: human_reused_actor")
    expect(outcome[:weight]).to be_nil
    expect(outcome[:raw]["matched_prior_leads"]).to contain_exactly("L-0912", "L-0977", "L-1044")
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
