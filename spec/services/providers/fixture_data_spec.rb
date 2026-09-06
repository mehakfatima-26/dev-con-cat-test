require "rails_helper"

RSpec.describe Providers::FixtureData do
  describe ".for" do
    it "returns the vpn_proxy fixture for a known lead" do
      result = described_class.for("vpn_proxy", "L-1001")

      expect(result).to include("is_vpn" => false, "is_datacenter" => false, "risk" => "low")
    end

    it "returns a different provider's fixture independently" do
      result = described_class.for("anura", "L-1002")

      expect(result).to include("result" => "bad", "invalid_traffic_type" => "bot")
    end

    it "returns nil for a lead_id with no fixture (a live, unmatched submission)" do
      expect(described_class.for("vpn_proxy", "L-does-not-exist")).to be_nil
    end

    it "loads every real provider file without error" do
      DetectionLayer::KEYS.without("duplicate_detection").each do |key|
        expect { described_class.file(key) }.not_to raise_error
      end
    end
  end
end
