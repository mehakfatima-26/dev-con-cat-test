require "rails_helper"

RSpec.describe Verification::RunLayer do
  let(:global_policy) { ConsensusPolicy.find_by(account: nil) || create(:consensus_policy, account: nil) }

  def policy_with(rules)
    create(:policy_version, consensus_policy: global_policy, rules: rules)
  end

  def run_for(lead_id, rules:, layer_key:)
    lead = create(:lead, lead_id: lead_id)
    run = create(:verification_run, lead: lead, policy_version: policy_with(rules))
    described_class.new(verification_run: run, layer_key: layer_key).call
  end

  let(:bot_hard_stop_rules) do
    { "anura" => { "hard_stop" => { "invalid_traffic_type" => [ "bot" ] } } }
  end

  it "charges credits for the layer even against mock data" do
    result = run_for("L-1001", rules: bot_hard_stop_rules, layer_key: "anura")

    charge = CreditTransaction.find_by(verification_run: result.verification_run, layer_key: "anura")
    expect(charge.amount).to eq(-DetectionLayer.cost("anura"))
  end

  describe "a hard stop (Anura L-1002: confirmed bot traffic)" do
    it "returns result: fail and stops without computing a weight" do
      result = run_for("L-1002", rules: bot_hard_stop_rules, layer_key: "anura")

      expect(result.result).to eq("fail")
      expect(result.detail).to eq("Invalid traffic type: bot")
      expect(result.weight).to be_nil
    end
  end

  describe "clean traffic (Anura L-1001: no signals)" do
    it "returns result: pass with zero weight" do
      result = run_for("L-1001", rules: bot_hard_stop_rules, layer_key: "anura")

      expect(result.result).to eq("pass")
      expect(result.detail).to eq("Anura: result is good, no fraud signals")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "a mapped weighted signal (vpn_proxy L-1003: vpn masking)" do
    it "returns result: warn with the configured weight (no confidence field on this provider, so unscaled)" do
      vpn_rules = {
        "vpn_proxy" => {
          "weighted" => {
            "vpn_detected" => { "weight" => 0.15, "label" => "VPN detected" },
            "datacenter_ip" => { "weight" => 0.15, "label" => "Datacenter IP" },
            "ip_mismatch" => { "weight" => 0.15, "label" => "IP mismatch" }
          }
        }
      }
      result = run_for("L-1003", rules: vpn_rules, layer_key: "vpn_proxy")

      expect(result.result).to eq("warn")
      expect(result.weight).to be_within(0.001).of(0.45)
    end
  end

  describe "multiple weighted signals summing together (vpn_proxy L-1002: Tor + datacenter + mismatch)" do
    it "sums every fired signal's weight" do
      vpn_rules = {
        "vpn_proxy" => {
          "weighted" => {
            "tor_exit" => { "weight" => 0.2, "label" => "Tor exit node" },
            "datacenter_ip" => { "weight" => 0.2, "label" => "Datacenter IP" },
            "ip_mismatch" => { "weight" => 0.2, "label" => "IP mismatch" }
          }
        }
      }
      result = run_for("L-1002", rules: vpn_rules, layer_key: "vpn_proxy")

      expect(result.result).to eq("warn")
      expect(result.weight).to be_within(0.001).of(0.6)
    end
  end

  describe "anura's raw-field containers (rule_ids and invalid_traffic_type)" do
    let(:anura_rules) do
      {
        "anura" => {
          "hard_stop" => {
            "invalid_traffic_type" => [ "bot" ]
          },
          "weighted" => {
            "rule_ids" => {
              "anonymizer_ip"      => { "weight" => 0.1, "label" => "Anonymizer IP (Anura)" },
              "datacenter_ip"      => { "weight" => 0.15, "label" => "Datacenter IP (Anura)" },
              "automation_tool"    => { "weight" => 0.3, "label" => "Automation tool detected" },
              "form_fill_too_fast" => { "weight" => 0.2, "label" => "Form filled too fast" }
            }
          }
        }
      }
    end

    it "finds a rule_ids-derived value nested under rule_ids (L-1003: anonymizer_ip)" do
      result = run_for("L-1003", rules: anura_rules, layer_key: "anura")

      # L-1003's invalid_traffic_type is "anonymizer" -- not a hard stop, and
      # the weighted phase only ever looks at rule_ids, so it's not examined
      # at all once it's ruled out as a hard stop. Only rule_ids drives weight.
      expect(result.result).to eq("warn")
      expect(result.detail).to eq("Anonymizer IP (Anura)")
      expect(result.weight).to be_within(0.001).of(0.1 * 0.61) # L-1003's own confidence
    end

    it "finds invalid_traffic_type nested under its own hard_stop container (L-1002: bot)" do
      result = run_for("L-1002", rules: anura_rules, layer_key: "anura")

      # rule_ids also fire weighted signals for L-1002, but the hard stop
      # from invalid_traffic_type wins outright regardless.
      expect(result.result).to eq("fail")
      expect(result.detail).to eq("Invalid traffic type: bot")
      expect(result.weight).to be_nil
    end

    it "sums nested rule_ids weights on their own when no hard stop fires (L-1002's rule_ids alone)" do
      weighted_only_rules = { "anura" => { "weighted" => anura_rules["anura"]["weighted"] } }
      result = run_for("L-1002", rules: weighted_only_rules, layer_key: "anura")

      expect(result.result).to eq("warn")
      expected = (0.15 + 0.3 + 0.2) * 0.99 # datacenter_ip + automation_tool + form_fill_too_fast, scaled by L-1002's confidence
      expect(result.weight).to be_within(0.001).of(expected)
    end

    it "treats an unconfigured invalid_traffic_type value as unrecognized, not silently clean (L-1009: human_fraud_farm)" do
      weighted_only_rules = { "anura" => { "weighted" => anura_rules["anura"]["weighted"] } }
      result = run_for("L-1009", rules: weighted_only_rules, layer_key: "anura")

      expect(result.result).to eq("warn")
      expect(result.detail).to include("unrecognized signal")
    end
  end

  describe "blacklist_alliance's raw status field (read directly, like anura's raw fields)" do
    let(:blacklist_rules) do
      {
        "blacklist_alliance" => {
          "hard_stop" => { "status" => [ "litigator" ] },
          "weighted" => { "status" => { "suspected" => { "weight" => 0.4, "label" => "Suspected litigator pattern match" } } }
        }
      }
    end

    it "hard-stops on a confirmed litigator (L-1005)" do
      result = run_for("L-1005", rules: blacklist_rules, layer_key: "blacklist_alliance")

      expect(result.result).to eq("fail")
      expect(result.detail).to eq("Lead is litigator, confirmed from 2 sources")
      expect(result.weight).to be_nil
    end

    it "treats a suspected match as weighted, scaled by match_score, not a hard stop (L-1011)" do
      result = run_for("L-1011", rules: blacklist_rules, layer_key: "blacklist_alliance")

      expect(result.result).to eq("warn")
      expect(result.detail).to eq("Suspected litigator pattern match, confirmed from 1 source")
      expect(result.weight).to be_within(0.001).of(0.4 * 0.58) # L-1011's own match_score
    end

    it "passes clean traffic with zero weight (L-1001)" do
      result = run_for("L-1001", rules: blacklist_rules, layer_key: "blacklist_alliance")

      expect(result.result).to eq("pass")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "dnc's raw dnc_status field (no weighted bucket -- binary hard-stop-or-callable)" do
    let(:dnc_rules) { { "dnc" => { "hard_stop" => { "dnc_status" => [ "dnc_listed", "internal_dnc" ] } } } }

    it "hard-stops a DNC-listed lead (L-1005)" do
      result = run_for("L-1005", rules: dnc_rules, layer_key: "dnc")

      expect(result.result).to eq("fail")
      expect(result.detail).to eq("DNC status is dnc_listed")
      expect(result.weight).to be_nil
    end

    it "passes a callable lead (L-1001)" do
      result = run_for("L-1001", rules: dnc_rules, layer_key: "dnc")

      expect(result.result).to eq("pass")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "email_validation's two independent axes (deliverable, disposable)" do
    let(:email_rules) do
      {
        "email_validation" => {
          "weighted" => {
            "both_undeliverable" => { "weight" => 0.4, "label" => "Both providers agree: undeliverable" },
            "both_disposable" => { "weight" => 0.35, "label" => "Both providers flag disposable domain" }
          }
        }
      }
    end

    it "fires both axes at once and sums their weight (L-1002)" do
      result = run_for("L-1002", rules: email_rules, layer_key: "email_validation")

      expect(result.result).to eq("warn")
      expect(result.weight).to be_within(0.001).of(0.75)
    end

    it "passes when both providers agree clean (L-1001)" do
      result = run_for("L-1001", rules: email_rules, layer_key: "email_validation")

      expect(result.result).to eq("pass")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "phone_validation's forgiven-disagreement logic (3 providers)" do
    let(:phone_rules) do
      {
        "phone_validation" => {
          "weighted" => {
            "validity_disagreement" => { "weight" => 0.2, "label" => "Providers disagree on validity" },
            "all_voip" => { "weight" => 0.3, "label" => "Confirmed VoIP line" }
          }
        }
      }
    end

    it "flags confirmed VoIP even with unanimous agreement (L-1009)" do
      result = run_for("L-1009", rules: phone_rules, layer_key: "phone_validation")

      expect(result.result).to eq("warn")
      expect(result.weight).to be_within(0.001).of(0.3)
    end

    it "passes when all three agree (L-1001)" do
      result = run_for("L-1001", rules: phone_rules, layer_key: "phone_validation")

      expect(result.result).to eq("pass")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "trustedform's raw status field (no weighted bucket -- binary hard-stop-or-verified)" do
    let(:trustedform_rules) { { "trustedform" => { "hard_stop" => { "status" => [ "mismatch", "expired", "not_found" ] } } } }

    it "hard-stops a mismatched certificate (L-1010)" do
      result = run_for("L-1010", rules: trustedform_rules, layer_key: "trustedform")

      expect(result.result).to eq("fail")
      expect(result.detail).to eq("Consent certificate status: mismatch")
      expect(result.weight).to be_nil
    end

    it "passes a verified certificate (L-1001)" do
      result = run_for("L-1001", rules: trustedform_rules, layer_key: "trustedform")

      expect(result.result).to eq("pass")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "enrichment's mutually exclusive signal buckets (2 sources)" do
    let(:enrichment_rules) do
      {
        "enrichment" => {
          "weighted" => {
            "identity_mismatch" => { "weight" => 0.35, "label" => "Enrichment source found a non-matching identity" },
            "single_source_match" => { "weight" => 0.15, "label" => "Only one enrichment source could confirm identity" }
          }
        }
      }
    end

    it "flags identity_mismatch when a source finds real but non-matching data (L-1011)" do
      result = run_for("L-1011", rules: enrichment_rules, layer_key: "enrichment")

      expect(result.result).to eq("warn")
      expect(result.weight).to be_within(0.001).of(0.35)
    end

    it "passes when both sources match and confirm the lead (L-1001)" do
      result = run_for("L-1001", rules: enrichment_rules, layer_key: "enrichment")

      expect(result.result).to eq("pass")
      expect(result.weight).to eq(0.0)
    end
  end

  describe "voice's not_applicable state (no sample captured)" do
    let(:voice_rules) { { "voice" => { "hard_stop" => { "verdict" => [ "human_reused_actor", "synthetic" ] } } } }

    it "persists state: not_applicable with no result/weight, and charges no credits (L-1001)" do
      lead = create(:lead, lead_id: "L-1001")
      run = create(:verification_run, lead: lead, policy_version: policy_with(voice_rules))

      result = described_class.new(verification_run: run, layer_key: "voice").call

      expect(result.state).to eq("not_applicable")
      expect(result.result).to be_nil
      expect(result.weight).to be_nil
      expect(CreditTransaction.where(verification_run: run, layer_key: "voice")).to be_empty
    end

    it "hard-stops a reused voice-actor and does charge credits (L-1009)" do
      result = run_for("L-1009", rules: voice_rules, layer_key: "voice")

      expect(result.state).to eq("completed")
      expect(result.result).to eq("fail")
      charge = CreditTransaction.find_by(verification_run: result.verification_run, layer_key: "voice")
      expect(charge.amount).to eq(-DetectionLayer.cost("voice"))
    end
  end

  describe "duplicate_detection (queries live CrmRecord, not a fixture)" do
    it "hard-stops an exact duplicate found in the account's own CRM" do
      account = create(:account)
      pixel = create(:pixel, account: account)
      lead = create(:lead, account: account, pixel: pixel, phone: "+17135550173", email: "patricia.nguyen@gmail.com")
      create(:crm_record, account: account, crm_id: "ME-88213", phone: lead.phone, email: lead.email)
      run = create(:verification_run, lead: lead, policy_version: policy_with({}))

      result = described_class.new(verification_run: run, layer_key: "duplicate_detection").call

      expect(result.result).to eq("fail")
      expect(result.detail).to eq("Exact duplicate of existing CRM record ME-88213")
    end
  end

  describe "an errored layer (adapter raises)" do
    it "persists state: errored without crashing, and does not charge credits" do
      lead = create(:lead, lead_id: "L-nonexistent")
      run = create(:verification_run, lead: lead, policy_version: policy_with({}))

      result = described_class.new(verification_run: run, layer_key: "anura").call

      expect(result.state).to eq("errored")
      expect(result.result).to be_nil
      expect(result.weight).to be_nil
      expect(result.detail).to include("anura failed")

      expect(CreditTransaction.where(verification_run: run, layer_key: "anura")).to be_empty
    end
  end

  describe "retrying a layer" do
    it "updates the existing errored row in place on a successful retry, and charges credits now" do
      lead = create(:lead, lead_id: "L-1001")
      run = create(:verification_run, lead: lead, policy_version: policy_with({}))
      existing = create(:layer_result, verification_run: run, layer_key: "anura",
        state: :errored, result: nil, weight: nil, detail: "anura failed: boom")

      result = described_class.new(verification_run: run, layer_key: "anura").call

      expect(result.id).to eq(existing.id)
      expect(result.state).to eq("completed")
      expect(result.result).to eq("pass")
      expect(result.detail).to eq("Anura: result is good, no fraud signals")
      expect(CreditTransaction.find_by(verification_run: run, layer_key: "anura")).to be_present
    end

    it "does not re-run or re-charge a layer that already completed" do
      lead = create(:lead, lead_id: "L-1001")
      run = create(:verification_run, lead: lead, policy_version: policy_with({}))
      existing = create(:layer_result, verification_run: run, layer_key: "anura",
        state: :completed, result: :pass, weight: 0.0, detail: "already done")

      result = described_class.new(verification_run: run, layer_key: "anura").call

      expect(result.id).to eq(existing.id)
      expect(result.detail).to eq("already done")
      expect(CreditTransaction.where(verification_run: run, layer_key: "anura")).to be_empty
    end
  end

  describe "an unrecognized signal" do
    it "marks the layer warn (not pass) and contributes no weight" do
      # anura is enabled, but the policy defines no rules for it at all --
      # none of its raw fields (rule_ids, invalid_traffic_type) have anywhere
      # to be looked up, so everything falls into the unrecognized-signal path.
      unrelated_rules = { "vpn_proxy" => { "is_vpn" => { "type" => "weighted", "weight" => 0.2, "label" => "VPN", "enabled" => true } } }
      policy = create(:policy_version, consensus_policy: global_policy, rules: unrelated_rules)
      lead = create(:lead, lead_id: "L-1002")
      run = create(:verification_run, lead: lead, policy_version: policy)

      result = described_class.new(verification_run: run, layer_key: "anura").call

      expect(result.result).to eq("warn")
      expect(result.detail).to include("unrecognized signal")
      expect(result.weight).to eq(0.0)
    end
  end
end
