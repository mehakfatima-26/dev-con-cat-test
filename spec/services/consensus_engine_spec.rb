require "rails_helper"

RSpec.describe ConsensusEngine do
  def row(layer_key, state:, result: nil, weight: nil, detail: "detail")
    build(:layer_result, layer_key: layer_key, state: state, result: result, weight: weight, detail: detail)
  end

  def policy(reject: 0.4, review: 0.9)
    build(:policy_version, thresholds: { "reject" => reject, "review" => review })
  end

  describe "algorithm" do
    it "accepts a run with zero signals" do
      rows = [ row("anura", state: :completed, result: :pass, weight: 0.0) ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("accept")
      expect(result[:score]).to eq(1.0)
      expect(result[:reasons]).to eq([])
    end

    it "rejects outright on any hard stop, regardless of what else passed" do
      rows = [
        row("dnc", state: :completed, result: :fail, detail: "DNC status is dnc_listed"),
        row("anura", state: :completed, result: :pass, weight: 0.0)
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("reject")
      expect(result[:score]).to eq(0.0)
      expect(result[:reason]).to eq("DNC status is dnc_listed")
      expect(result[:hard_stops]).to eq([ "dnc" ])
    end

    it "collects every hard stop's reason, not just the first" do
      rows = [
        row("dnc", state: :completed, result: :fail, detail: "DNC status is dnc_listed"),
        row("trustedform", state: :completed, result: :fail, detail: "Consent certificate status: expired")
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:reasons]).to contain_exactly(
        "dnc: DNC status is dnc_listed", "trustedform: Consent certificate status: expired"
      )
    end

    it "floors at review when a consent-critical layer errored, even with an otherwise clean score" do
      critical_policy = build(:policy_version,
        rules: { "trustedform" => { "hard_stop" => { "status" => [ "mismatch", "expired", "not_found" ] } } },
        thresholds: { "reject" => 0.4, "review" => 0.9 })
      rows = [
        row("trustedform", state: :errored, detail: "trustedform failed: timeout"),
        row("anura", state: :completed, result: :pass, weight: 0.0)
      ]

      result = described_class.call(layer_results: rows, policy_version: critical_policy)

      expect(result[:verdict]).to eq("review")
      expect(result[:reason]).to eq("Could not verify trustedform: trustedform failed: timeout")
    end

    it "treats ANY layer the active policy gives hard-stop rules to as critical, not just a fixed list" do
      policy_with_anura_critical = build(:policy_version,
        rules: { "anura" => { "hard_stop" => { "invalid_traffic_type" => [ "bot" ] } } },
        thresholds: { "reject" => 0.4, "review" => 0.9 })
      rows = [ row("anura", state: :errored, detail: "anura failed: timeout") ]

      result = described_class.call(layer_results: rows, policy_version: policy_with_anura_critical)

      expect(result[:verdict]).to eq("review")
    end

    it "does not float a hard stop up to review just because another layer also errored" do
      rows = [
        row("dnc", state: :completed, result: :fail, detail: "DNC status is dnc_listed"),
        row("trustedform", state: :errored, detail: "trustedform failed: timeout")
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("reject")
    end

    it "does not floor on a non-critical layer erroring" do
      rows = [
        row("vpn_proxy", state: :errored, detail: "vpn_proxy failed: timeout"),
        row("anura", state: :completed, result: :pass, weight: 0.0)
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("accept")
    end

    it "ignores skipped layers entirely" do
      rows = [
        row("duplicate_detection", state: :completed, result: :fail, detail: "Exact duplicate of existing CRM record X"),
        row("anura", state: :skipped)
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("reject")
      expect(result[:reasons]).to eq([ "duplicate_detection: Exact duplicate of existing CRM record X" ])
    end

    it "ignores not_applicable layers for scoring" do
      rows = [
        row("voice", state: :not_applicable, detail: "No voice sample captured for this lead"),
        row("anura", state: :completed, result: :pass, weight: 0.0)
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("accept")
    end

    it "sums warn weights into a single score and lands review below the review threshold" do
      rows = [ row("email_validation", state: :completed, result: :warn, weight: 0.35, detail: "Both providers agree: undeliverable") ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("review")
      expect(result[:score]).to be_within(0.001).of(0.65)
    end

    it "rejects on accumulated weighted score alone, with no hard stop at all" do
      rows = [
        row("anura", state: :completed, result: :warn, weight: 0.4, detail: "Fraud-farm device cluster"),
        row("phone_validation", state: :completed, result: :warn, weight: 0.3, detail: "All providers agree: VoIP")
      ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("reject")
      expect(result[:score]).to be_within(0.001).of(0.3)
    end

    it "never returns an empty reasons list for a non-accept verdict" do
      rows = [ row("blacklist_alliance", state: :completed, result: :warn, weight: 0.2, detail: "Suspected litigator pattern match") ]

      result = described_class.call(layer_results: rows, policy_version: policy)

      expect(result[:verdict]).to eq("review")
      expect(result[:reasons]).not_to be_empty
    end
  end

  describe "the 12 seed leads, run through the real adapters against the real fixtures" do
    let(:rules) { {
      "vpn_proxy" => {
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
      },
      "duplicate_detection" => {
        "weighted" => { "soft_duplicate" => { "weight" => 0.05, "label" => "Soft duplicate CRM match" } }
      },
      "anura" => {
        "hard_stop" => { "invalid_traffic_type" => [ "bot" ] },
        "weighted" => {
          "rule_ids" => {
            "datacenter_ip" => { "weight" => 0.2, "label" => "Datacenter-origin IP (Anura)" },
            "automation_tool" => { "weight" => 0.35, "label" => "Automation tooling detected (Anura)" },
            "form_fill_too_fast" => { "weight" => 0.25, "label" => "Form filled implausibly fast (Anura)" },
            "anonymizer_ip" => { "weight" => 0.2, "label" => "Anonymizer IP (Anura)" },
            "device_reputation_low" => { "weight" => 0.15, "label" => "Low device reputation (Anura)" },
            "fraud_farm_cluster" => { "weight" => 0.35, "label" => "Fraud-farm device cluster (Anura)" },
            "repeat_device_multi_identity" => { "weight" => 0.3, "label" => "Same device across multiple identities (Anura)" }
          }
        },
        "max_weight" => 0.4
      },
      "trustedform" => { "hard_stop" => { "status" => [ "mismatch", "expired", "not_found" ] } },
      "blacklist_alliance" => {
        "hard_stop" => { "status" => [ "litigator" ] },
        "weighted" => { "status" => { "suspected" => { "weight" => 0.3, "label" => "Suspected TCPA litigator pattern match" } } }
      },
      "dnc" => { "hard_stop" => { "dnc_status" => [ "dnc_listed", "internal_dnc" ] } },
      "phone_validation" => {
        "weighted" => {
          "all_invalid" => { "weight" => 0.4, "label" => "No provider found this number valid" },
          "validity_disagreement" => { "weight" => 0.15, "label" => "Providers disagree on number validity" },
          "line_type_disagreement" => { "weight" => 0.1, "label" => "Providers disagree on line type" },
          "all_voip" => { "weight" => 0.3, "label" => "All providers agree: VoIP line (disposable/reseller-prone)" }
        }
      },
      "email_validation" => {
        "weighted" => {
          "both_undeliverable" => { "weight" => 0.35, "label" => "Both providers agree: undeliverable" },
          "both_disposable" => { "weight" => 0.3, "label" => "Both providers agree: disposable/throwaway domain" },
          "deliverable_disagreement" => { "weight" => 0.15, "label" => "Providers disagree on deliverability" },
          "disposable_disagreement" => { "weight" => 0.15, "label" => "Providers disagree on disposable/throwaway status" }
        },
        "max_weight" => 0.5
      },
      "enrichment" => {
        "weighted" => {
          "identity_mismatch" => { "weight" => 0.25, "label" => "Enrichment source found a non-matching identity" },
          "single_source_match" => { "weight" => 0.15, "label" => "Only one enrichment source could confirm identity" },
          "no_enrichment_data" => { "weight" => 0.1, "label" => "No enrichment data from either source" }
        }
      },
      "voice" => { "hard_stop" => { "verdict" => [ "human_reused_actor", "synthetic" ] } }
    } }

    let(:thresholds) { { "reject" => 0.4, "review" => 0.9 } }

    let(:solarpro) { create(:account, enabled_modules: %w[anura trustedform dnc blacklist_alliance phone_validation email_validation vpn_proxy enrichment duplicate_detection]) }
    let(:medicareedge) do
      account = create(:account, enabled_modules: %w[anura trustedform dnc blacklist_alliance phone_validation email_validation enrichment duplicate_detection voice])
      create(:crm_record, account: account, crm_id: "ME-88213", first_name: "Patricia", last_name: "Nguyen",
        phone: "+17135550173", email: "patricia.nguyen@gmail.com", crm_created_at: "2026-06-28T09:15:00Z")
      account
    end
    let(:autoinsure) do
      account = create(:account, enabled_modules: %w[anura trustedform dnc phone_validation duplicate_detection])
      create(:crm_record, account: account, crm_id: "AI-55019", first_name: "Emily", last_name: "Watson",
        phone: "+16465550193", email: "emily.watson.personal@gmail.com", crm_created_at: "2026-07-19T22:05:00Z")
      account
    end

    def lead_for(account, lead_id:, phone:, email:)
      pixel = create(:pixel, account: account)
      build(:lead, account: account, pixel: pixel, lead_id: lead_id, phone: phone, email: email)
    end

    def run_layer_locally(lead, key)
      outcome = "Layers::#{key.camelize}".constantize.new(lead, rules[key] || {}).call

      if outcome[:not_applicable]
        build(:layer_result, layer_key: key, state: :not_applicable, result: nil, weight: nil, detail: outcome[:detail])
      else
        build(:layer_result, layer_key: key, state: :completed, result: outcome[:result], weight: outcome[:weight], detail: outcome[:detail])
      end
    end

    def verdict_for(lead, account)
      rows = account.enabled_modules.map { |key| run_layer_locally(lead, key) }
      described_class.call(layer_results: rows, policy_version: build(:policy_version, thresholds: thresholds))
    end

    it "L-1001: clean lead, no signals at all -- accept" do
      lead = lead_for(solarpro, lead_id: "L-1001", phone: "+13105550142", email: "maria.gonzalez@gmail.com")
      expect(verdict_for(lead, solarpro)[:verdict]).to eq("accept")
    end

    it "L-1002: confirmed bot traffic -- reject via anura hard stop" do
      lead = lead_for(solarpro, lead_id: "L-1002", phone: "+12025550188", email: "jsmith9981@mail-tempz.example")
      result = verdict_for(lead, solarpro)
      expect(result[:verdict]).to eq("reject")
      expect(result[:hard_stops]).to include("anura")
    end

    it "L-1003: single weak suspect signal (anonymizer, no hard stop) -- review" do
      lead = lead_for(medicareedge, lead_id: "L-1003", phone: "+14045550110", email: "daniel.okafor@outlook.com")
      expect(verdict_for(lead, medicareedge)[:verdict]).to eq("review")
    end

    it "L-1004: exact CRM duplicate (same phone AND email as ME-88213) -- reject via duplicate_detection hard stop" do
      lead = lead_for(medicareedge, lead_id: "L-1004", phone: "+17135550173", email: "patricia.nguyen@gmail.com")
      result = verdict_for(lead, medicareedge)
      expect(result[:verdict]).to eq("reject")
      expect(result[:hard_stops]).to include("duplicate_detection")
    end

    it "L-1005: DNC-listed -- reject via dnc hard stop" do
      lead = lead_for(autoinsure, lead_id: "L-1005", phone: "+18185550199", email: "rvance.legal@protonmail.example")
      expect(verdict_for(lead, autoinsure)[:verdict]).to eq("reject")
    end

    it "L-1006: DNC-listed -- reject via dnc hard stop" do
      lead = lead_for(autoinsure, lead_id: "L-1006", phone: "+16025550120", email: "linda.carter@yahoo.com")
      expect(verdict_for(lead, autoinsure)[:verdict]).to eq("reject")
    end

    it "L-1007: weak anura + phone disagreement + vpn medium risk, no hard stop -- review, not reject" do
      lead = lead_for(solarpro, lead_id: "L-1007", phone: "+13215550164", email: "kevin.brooks@gmail.com")
      result = verdict_for(lead, solarpro)
      expect(result[:verdict]).to eq("review")
    end

    it "L-1008: email undeliverable on both providers, nothing else -- review" do
      lead = lead_for(medicareedge, lead_id: "L-1008", phone: "+13055550135", email: "grace.adeyemi@nо-such-domain.example")
      expect(verdict_for(lead, medicareedge)[:verdict]).to eq("review")
    end

    it "L-1009: acct_autoinsure's under-bought coverage -- reject on anura + phone_validation alone, no hard stop" do
      lead = lead_for(autoinsure, lead_id: "L-1009", phone: "+15125550157", email: "marcus.hill.24@gmail.com")
      result = verdict_for(lead, autoinsure)
      expect(result[:verdict]).to eq("reject")
      expect(result[:hard_stops]).to eq([])
    end

    it "L-1010: trustedform mismatch -- reject via hard stop" do
      lead = lead_for(solarpro, lead_id: "L-1010", phone: "+19495550181", email: "sofia.ramirez@gmail.com")
      expect(verdict_for(lead, solarpro)[:verdict]).to eq("reject")
    end

    it "L-1011: three separate weak/moderate signals stacking, still no hard stop -- review, not reject" do
      lead = lead_for(medicareedge, lead_id: "L-1011", phone: "+12145550149", email: "james.obrien@gmail.com")
      expect(verdict_for(lead, medicareedge)[:verdict]).to eq("review")
    end

    it "L-1012: only a soft/partial CRM match (different email) -- still accept, not blocked by a mere possible-duplicate" do
      lead = lead_for(autoinsure, lead_id: "L-1012", phone: "+16465550193", email: "emily.watson@gmail.com")
      result = verdict_for(lead, autoinsure)
      expect(result[:verdict]).to eq("accept")
      expect(result[:reasons]).to contain_exactly(a_string_matching(/Soft duplicate CRM match/))
    end
  end
end
