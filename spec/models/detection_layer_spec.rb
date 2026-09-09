require "rails_helper"

RSpec.describe DetectionLayer do
  it "exposes the 10 layer keys from the seed data's module_costs_in_credits" do
    expect(DetectionLayer::KEYS).to contain_exactly(
      "vpn_proxy", "anura", "trustedform", "blacklist_alliance", "dnc",
      "phone_validation", "email_validation", "enrichment", "duplicate_detection", "voice"
    )
  end

  it "returns the correct credit cost for a known layer" do
    expect(DetectionLayer.cost("voice")).to eq(5)
    expect(DetectionLayer.cost("dnc")).to eq(1)
  end

  it "raises for an unknown layer" do
    expect { DetectionLayer.cost("not_a_real_layer") }.to raise_error(KeyError)
  end
end
