require "rails_helper"

RSpec.describe Layers::VpnProxy do
  let(:rules) do
    {
      "weighted" => {
        "tor_exit" => { "weight" => 0.35, "label" => "Tor exit node detected" },
        "proxy_detected" => { "weight" => 0.25, "label" => "Anonymizing proxy detected" },
        "vpn_detected" => { "weight" => 0.15, "label" => "Commercial VPN detected" },
        "datacenter_ip" => { "weight" => 0.15, "label" => "Datacenter-origin IP" },
        "ip_mismatch" => { "weight" => 0.15, "label" => "Site-visit IP does not match submission IP" },
        "risk_low" => { "weight" => 0.0, "label" => "Provider composite risk: low" },
        "risk_medium" => { "weight" => 0.2, "label" => "Provider composite risk: medium" },
        "risk_high" => { "weight" => 0.4, "label" => "Provider composite risk: high" }
      },
      "max_weight" => 0.5
    }
  end

  describe "clean traffic, nothing to report (L-1001, L-1004, L-1005, L-1006, L-1008, L-1010, L-1011, L-1012)" do
    %w[L-1001 L-1004 L-1005 L-1006 L-1008 L-1010 L-1011 L-1012].each do |lead_id|
      it "passes #{lead_id}" do
        outcome = described_class.new(build(:lead, lead_id: lead_id), rules).call

        expect(outcome[:result]).to eq("pass")
        expect(outcome[:weight]).to eq(0.0)
      end
    end
  end

  it "the risk floor catches what the discrete booleans miss (L-1007: every boolean false, risk medium from device reputation)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1007"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:weight]).to eq(0.2)
    expect(outcome[:detail]).to eq(
      "Provider composite risk: medium; Residential IP but device reputation is low; kept as medium."
    )
  end

  it "combines discrete signals below the cap (L-1003: VPN + datacenter + IP mismatch, risk high)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1003"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:weight]).to be_within(0.001).of(0.45)
    expect(outcome[:detail]).to eq(
      "Commercial VPN detected; Datacenter-origin IP; Site-visit IP does not match submission IP; " \
      "Commercial VPN (NordVPN ASN). Site visit came from a residential IP; submission from VPN — classic VPN masking."
    )
  end

  it "caps the total at max_weight even when every signal fires (L-1002: Tor + datacenter + IP mismatch)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1002"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:weight]).to eq(0.5)
    expect(outcome[:detail]).to eq(
      "Tor exit node detected; Datacenter-origin IP; Site-visit IP does not match submission IP; " \
      "Tor exit node + datacenter ASN."
    )
  end

  it "prioritizes proxy over vpn when both are true, and still caps at max_weight (L-1009: proxy pool)" do
    outcome = described_class.new(build(:lead, lead_id: "L-1009"), rules).call

    expect(outcome[:result]).to eq("warn")
    expect(outcome[:weight]).to eq(0.5)
    expect(outcome[:detail]).to eq(
      "Anonymizing proxy detected; Datacenter-origin IP; Site-visit IP does not match submission IP; " \
      "Datacenter proxy pool; multiple identities seen from same /24 (see anura fraud-farm signal)."
    )
  end

  it "does not double-count when a signal is configured as a hard stop instead of weighted" do
    hard_stop_rules = { "hard_stop" => [ "tor_exit" ], "weighted" => rules["weighted"] }
    outcome = described_class.new(build(:lead, lead_id: "L-1002"), hard_stop_rules).call

    expect(outcome[:result]).to eq("fail")
    expect(outcome[:detail]).to eq("VPN/proxy: Tor exit node detected")
    expect(outcome[:weight]).to be_nil
  end

  it "raises when asked about a lead with no fixture" do
    expect {
      described_class.new(build(:lead, lead_id: "L-nonexistent"), {}).call
    }.to raise_error(NotImplementedError, /SimulatedSource/)
  end
end
