require "rails_helper"

RSpec.describe Layers::Enrichment do
  let(:rules) do
    {
      "weighted" => {
        "identity_mismatch" => { "weight" => 0.35, "label" => "Enrichment source found a non-matching identity" },
        "single_source_match" => { "weight" => 0.15, "label" => "Only one enrichment source could confirm identity" },
        "no_enrichment_data" => { "weight" => 0.1, "label" => "No enrichment data from either source" }
      }
    }
  end

  it "passes when both sources match and confirm the lead (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "flags no_enrichment_data when neither source finds anything (L-1002)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1002"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("No enrichment data from either source")
    expect(outcome[:weight]).to be_within(0.001).of(0.1)
  end

  it "flags single_source_match when only one source can confirm identity (L-1009)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1009"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Only one enrichment source could confirm identity")
    expect(outcome[:weight]).to be_within(0.001).of(0.15)
  end

  it "flags identity_mismatch when a source finds real but non-matching data (L-1011)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1011"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Enrichment source found a non-matching identity")
    expect(outcome[:weight]).to be_within(0.001).of(0.35)
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
