require "rails_helper"

RSpec.describe Layers::PhoneValidation do
  let(:rules) do
    {
      "weighted" => {
        "all_invalid" => { "weight" => 0.4, "label" => "All providers agree: invalid" },
        "validity_disagreement" => { "weight" => 0.2, "label" => "Providers disagree on validity" },
        "all_voip" => { "weight" => 0.3, "label" => "Confirmed VoIP line" },
        "line_type_disagreement" => { "weight" => 0.15, "label" => "Providers disagree on line type" }
      }
    }
  end

  it "passes when all three agree: valid, same line type (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "flags validity disagreement when only one provider is valid, uncorroborated (L-1002)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1002"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Providers disagree on validity")
    expect(outcome[:weight]).to be_within(0.001).of(0.2)
  end

  it "flags both validity and line-type disagreement when the 2 valid providers don't corroborate each other (L-1007: mobile vs voip)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1007"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to include("Providers disagree on validity")
    expect(outcome[:detail]).to include("Providers disagree on line type")
    expect(outcome[:weight]).to be_within(0.001).of(0.35)
  end

  it "flags confirmed VoIP even with unanimous agreement, no disagreement involved (L-1009)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1009"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Confirmed VoIP line")
    expect(outcome[:weight]).to be_within(0.001).of(0.3)
  end

  it "flags line-type disagreement when all are valid but disagree on type (L-1011: landline/mobile/landline)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1011"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Providers disagree on line type")
    expect(outcome[:weight]).to be_within(0.001).of(0.15)
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
