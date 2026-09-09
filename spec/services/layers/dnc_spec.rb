require "rails_helper"

RSpec.describe Layers::Dnc do
  let(:rules) { { "hard_stop" => { "dnc_status" => [ "dnc_listed", "internal_dnc" ] } } }

  it "passes a callable lead and notes the open callback window (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:detail]).to eq("DNC status is callable, callback window is open")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "hard-stops a national+state DNC listing (L-1005)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1005"), rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("DNC status is dnc_listed")
    expect(outcome[:weight]).to be_nil
  end

  it "hard-stops a national-only DNC listing the same as national+state (L-1006)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1006"), rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("DNC status is dnc_listed")
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
