require "rails_helper"

RSpec.describe Layers::Anura do
  let(:bot_hard_stop_rules) { { "hard_stop" => { "invalid_traffic_type" => [ "bot" ] } } }

  it "hard-stops on a confirmed bot (L-1002)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1002"), bot_hard_stop_rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("Invalid traffic type: bot")
    expect(outcome[:weight]).to be_nil
    expect(outcome[:raw]["rule_ids"]).to contain_exactly("DATACENTER_IP", "AUTOMATION_TOOL", "FORM_FILL_TOO_FAST")
  end

  it "passes clean traffic outright when result is good (L-1001), even with rules configured" do
    outcome = described_class.new(build(:lead, lead_id: "L-1001"), bot_hard_stop_rules).call

    expect(outcome[:result]).to eq("pass")
    expect(outcome[:weight]).to eq(0.0)
  end

  it "sums weighted rule_ids when result is suspect and no hard stop fires (L-1003)" do
    rules = { "weighted" => { "rule_ids" => { "anonymizer_ip" => { "weight" => 0.1, "label" => "Anonymizer IP (Anura)" } } } }
    outcome = described_class.new(build(:lead, lead_id: "L-1003"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:detail]).to eq("Anonymizer IP (Anura)")
    expect(outcome[:weight]).to be_within(0.001).of(0.1 * 0.61) # L-1003's own confidence
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
