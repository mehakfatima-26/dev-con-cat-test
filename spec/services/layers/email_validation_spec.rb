require "rails_helper"

RSpec.describe Layers::EmailValidation do
  let(:rules) do
    {
      "weighted" => {
        "both_undeliverable" => { "weight" => 0.4, "label" => "Both providers agree: undeliverable" },
        "deliverable_disagreement" => { "weight" => 0.15, "label" => "Providers disagree on deliverability" },
        "both_disposable" => { "weight" => 0.35, "label" => "Both providers flag disposable domain" },
        "disposable_disagreement" => { "weight" => 0.1, "label" => "Providers disagree on disposable domain" }
      }
    }
  end

  it "passes when both providers agree: deliverable, not disposable (L-1001)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "fires both_undeliverable and both_disposable together, summing weight (L-1002)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1002"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to include("Both providers agree: undeliverable")
    expect(outcome[:detail]).to include("Both providers flag disposable domain")
    expect(outcome[:weight]).to be_within(0.001).of(0.75)
  end

  it "fires only both_undeliverable when disposable is clean on both sides (L-1008)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1008"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Both providers agree: undeliverable")
    expect(outcome[:weight]).to be_within(0.001).of(0.4)
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
