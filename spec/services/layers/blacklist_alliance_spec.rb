require "rails_helper"

RSpec.describe Layers::BlacklistAlliance do
  let(:rules) do
    {
      "hard_stop" => { "status" => [ "litigator" ] },
      "weighted" => { "status" => { "suspected" => { "weight" => 0.4, "label" => "Suspected litigator pattern match" } } }
    }
  end

  it "passes a clean lead (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "passes clean even with a nonzero noise match_score (L-1007)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1007"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:raw]["match_score"]).to eq(3)
  end

  it "hard-stops a confirmed litigator, naming the source count (L-1005: 2 sources)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1005"), rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("Lead is litigator, confirmed from 2 sources")
    expect(outcome[:weight]).to be_nil
  end

  it "weights a suspected match, scaled by match_score, not a flat weight (L-1011: match_score 58, 1 source)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1011"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Suspected litigator pattern match, confirmed from 1 source")
    expect(outcome[:weight]).to be_within(0.001).of(0.4 * 0.58)
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
