# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------
puts "== Accounts =="

ACCOUNTS = {
  "acct_solarpro" => {
    company_name: "SolarPro Leads LLC", plan: :growth, monthly_credit_allowance: 25_000,
    cycle_start: Date.new(2026, 7, 1), cycle_end: Date.new(2026, 7, 31), status: :active,
    enabled_modules: %w[anura trustedform dnc blacklist_alliance phone_validation email_validation vpn_proxy enrichment duplicate_detection],
    avg_daily_burn: 1_140, billing_contact: "ops@solarpro.example",
    origin: "https://solar-savings.example.com"
  },
  "acct_medicareedge" => {
    company_name: "Medicare Edge Marketing", plan: :enterprise, monthly_credit_allowance: 120_000,
    cycle_start: Date.new(2026, 7, 1), cycle_end: Date.new(2026, 7, 31), status: :active,
    enabled_modules: %w[anura trustedform dnc blacklist_alliance phone_validation email_validation enrichment duplicate_detection voice],
    avg_daily_burn: 2_480, billing_contact: "compliance@medicareedge.example",
    origin: "https://medicare-help.example.com"
  },
  "acct_autoinsure" => {
    company_name: "AutoInsure Direct", plan: :starter, monthly_credit_allowance: 8_000,
    cycle_start: Date.new(2026, 7, 1), cycle_end: Date.new(2026, 7, 31), status: :past_due,
    enabled_modules: %w[anura trustedform dnc phone_validation duplicate_detection],
    avg_daily_burn: 410, billing_contact: "founder@autoinsure.example",
    origin: "https://auto-quotes.example.com"
  }
}.freeze

accounts = ACCOUNTS.each_with_object({}) do |(account_id, attrs), memo|
  account = Account.find_or_create_by!(account_id: account_id) do |a|
    a.company_name = attrs[:company_name]
    a.plan = attrs[:plan]
    a.monthly_credit_allowance = attrs[:monthly_credit_allowance]
    a.cycle_start = attrs[:cycle_start]
    a.cycle_end = attrs[:cycle_end]
    a.status = attrs[:status]
    a.enabled_modules = attrs[:enabled_modules]
    a.avg_daily_burn = attrs[:avg_daily_burn]
    a.billing_contact = attrs[:billing_contact]
  end
  memo[account_id] = account
  puts "  #{account.account_id} (#{account.company_name}) -- #{account.enabled_modules.size}/#{DetectionLayer::KEYS.size} modules enabled"
end

# ---------------------------------------------------------------------------
# Users -- one super_admin (no account) + one account_admin per account
# ---------------------------------------------------------------------------
puts "\n== Users =="

User.find_or_create_by!(email: "admin@catchingconsent.example") do |u|
  u.user_id = "u_super_admin"
  u.name = "Platform Admin"
  u.role = :super_admin
  u.account = nil
  u.password = DEV_PASSWORD
end
puts "  admin@catchingconsent.example (super_admin, password: #{DEV_PASSWORD})"

accounts.each_value do |account|
  user = User.find_or_create_by!(email: account.billing_contact) do |u|
    u.user_id = "u_#{account.account_id}"
    u.name = "#{account.company_name} Admin"
    u.role = :account_admin
    u.account = account
    u.password = DEV_PASSWORD
  end
  puts "  #{user.email} (account_admin, #{account.account_id})"
end

# ---------------------------------------------------------------------------
# Pixels -- one per account, pixel_id fixed to match leads.json
# ---------------------------------------------------------------------------
puts "\n== Pixels =="

PIXEL_IDS = { "acct_solarpro" => "px_9f2a01", "acct_medicareedge" => "px_3b7c22", "acct_autoinsure" => "px_7d51f0" }.freeze

pixels = accounts.each_with_object({}) do |(account_id, account), memo|
  pixel = Pixel.find_or_create_by!(pixel_id: PIXEL_IDS.fetch(account_id)) do |p|
    p.account = account
    p.name = "#{account.company_name} Landing Page"
    p.signing_secret = SecureRandom.hex(20)
    p.allowed_origins = [ ACCOUNTS.fetch(account_id)[:origin] ]
  end
  memo[account_id] = pixel
  puts "  #{pixel.pixel_id} -> #{account_id}"
end

# ---------------------------------------------------------------------------
# Global default consensus policy - the exact rules/thresholds already
# proven against all 12 leads in spec/services/consensus_engine_spec.rb
# ---------------------------------------------------------------------------
puts "\n== Consensus policy =="

DEFAULT_RULES = {
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
}.freeze

DEFAULT_THRESHOLDS = { "reject" => 0.4, "review" => 0.9 }.freeze

global_policy = ConsensusPolicy.find_or_create_by!(account: nil) { |p| p.name = "Global default" }

if global_policy.active_policy_version.nil?
  version = global_policy.policy_versions.create!(
    version: 1, rules: DEFAULT_RULES, thresholds: DEFAULT_THRESHOLDS,
    notes: "Initial default policy -- validated against all 12 seed leads (spec/services/consensus_engine_spec.rb)"
  )
  global_policy.update!(active_policy_version: version)
  puts "  Created global default policy, version 1 (#{DetectionLayer::KEYS.size - DEFAULT_RULES.size} layer(s) with no rules configured: #{DetectionLayer::KEYS - DEFAULT_RULES.keys})"
else
  puts "  Global default policy already active (version #{global_policy.active_policy_version.version})"
end

# ---------------------------------------------------------------------------
# CRM records -- pre-existing records each account already had, from buyers_crm.json
# ---------------------------------------------------------------------------
puts "\n== CRM records =="

CRM_RECORDS = {
  "acct_solarpro" => [
    { crm_id: "SP-40021", first_name: "Alan", last_name: "Reyes", email: "alan.reyes@gmail.com", phone: "+13105550111", crm_created_at: "2026-05-11T10:00:00Z" },
    { crm_id: "SP-40088", first_name: "Maria", last_name: "Gonzalez", email: "maria.g.old@yahoo.com", phone: "+13105550999", crm_created_at: "2026-06-02T12:30:00Z" }
  ],
  "acct_medicareedge" => [
    { crm_id: "ME-88213", first_name: "Patricia", last_name: "Nguyen", email: "patricia.nguyen@gmail.com", phone: "+17135550173", crm_created_at: "2026-06-28T09:15:00Z" },
    { crm_id: "ME-88410", first_name: "Howard", last_name: "Kim", email: "howard.kim@gmail.com", phone: "+17135550100", crm_created_at: "2026-07-01T14:45:00Z" }
  ],
  "acct_autoinsure" => [
    { crm_id: "AI-55019", first_name: "Emily", last_name: "Watson", email: "emily.watson.personal@gmail.com", phone: "+16465550193", crm_created_at: "2026-07-19T22:05:00Z" }
  ]
}.freeze

CRM_RECORDS.each do |account_id, records|
  account = accounts.fetch(account_id)
  records.each do |attrs|
    CrmRecord.find_or_create_by!(account: account, crm_id: attrs[:crm_id]) do |r|
      r.first_name = attrs[:first_name]
      r.last_name = attrs[:last_name]
      r.email = attrs[:email]
      r.phone = attrs[:phone]
      r.crm_created_at = attrs[:crm_created_at]
    end
  end
  puts "  #{account_id}: #{records.size} pre-existing record(s)"
end

# ---------------------------------------------------------------------------
# The 12 leads -- created, then run through the REAL pipeline synchronously
# ---------------------------------------------------------------------------
puts "\n== Leads (running the real verification pipeline) =="

LEADS = [
  { lead_id: "L-1001", account_id: "acct_solarpro", captured_at: "2026-07-14T15:02:11Z", landing_page_url: "https://solar-savings.example.com/quote", campaign: "solar-google-search", first_name: "Maria", last_name: "Gonzalez", email: "maria.gonzalez@gmail.com", phone: "+13105550142", ip_address: "76.14.201.33", user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", trusted_form_cert_url: "https://cert.trustedform.example/0a1b2c3d4e5f6071829304a5b6c7d8e9", form_dwell_ms: 48210, expected_verdict: "ACCEPT" },
  { lead_id: "L-1002", account_id: "acct_solarpro", captured_at: "2026-07-14T15:07:44Z", landing_page_url: "https://solar-savings.example.com/quote", campaign: "solar-fb-lookalike", first_name: "John", last_name: "Smith", email: "jsmith9981@mail-tempz.example", phone: "+12025550188", ip_address: "185.220.101.7", user_agent: "python-requests/2.31.0", trusted_form_cert_url: "https://cert.trustedform.example/aa11bb22cc33dd44ee55ff6677889900", form_dwell_ms: 640, expected_verdict: "REJECT" },
  { lead_id: "L-1003", account_id: "acct_medicareedge", captured_at: "2026-07-14T15:12:03Z", landing_page_url: "https://medicare-help.example.com/enroll", campaign: "medicare-native", first_name: "Daniel", last_name: "Okafor", email: "daniel.okafor@outlook.com", phone: "+14045550110", ip_address: "45.83.220.14", user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", trusted_form_cert_url: "https://cert.trustedform.example/bb22cc33dd44ee55ff667788990011aa", form_dwell_ms: 22140, expected_verdict: "REVIEW" },
  { lead_id: "L-1004", account_id: "acct_medicareedge", captured_at: "2026-07-14T15:19:55Z", landing_page_url: "https://medicare-help.example.com/enroll", campaign: "medicare-native", first_name: "Patricia", last_name: "Nguyen", email: "patricia.nguyen@gmail.com", phone: "+17135550173", ip_address: "99.203.14.88", user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", trusted_form_cert_url: "https://cert.trustedform.example/cc33dd44ee55ff667788990011aabb22", form_dwell_ms: 31980, expected_verdict: "REJECT_DUPLICATE" },
  { lead_id: "L-1005", account_id: "acct_autoinsure", captured_at: "2026-07-14T15:24:31Z", landing_page_url: "https://auto-quotes.example.com/start", campaign: "auto-google-search", first_name: "Robert", last_name: "Vance", email: "rvance.legal@protonmail.example", phone: "+18185550199", ip_address: "68.100.44.12", user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", trusted_form_cert_url: "https://cert.trustedform.example/dd44ee55ff667788990011aabb22cc33", form_dwell_ms: 51220, expected_verdict: "REJECT" },
  { lead_id: "L-1006", account_id: "acct_autoinsure", captured_at: "2026-07-14T15:29:10Z", landing_page_url: "https://auto-quotes.example.com/start", campaign: "auto-bing-search", first_name: "Linda", last_name: "Carter", email: "linda.carter@yahoo.com", phone: "+16025550120", ip_address: "24.14.88.201", user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15", trusted_form_cert_url: "https://cert.trustedform.example/ee55ff667788990011aabb22cc33dd44", form_dwell_ms: 40100, expected_verdict: "REJECT" },
  { lead_id: "L-1007", account_id: "acct_solarpro", captured_at: "2026-07-14T15:33:47Z", landing_page_url: "https://solar-savings.example.com/quote", campaign: "solar-google-search", first_name: "Kevin", last_name: "Brooks", email: "kevin.brooks@gmail.com", phone: "+13215550164", ip_address: "70.199.22.140", user_agent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36", trusted_form_cert_url: "https://cert.trustedform.example/ff667788990011aabb22cc33dd44ee55", form_dwell_ms: 18730, expected_verdict: "REVIEW" },
  { lead_id: "L-1008", account_id: "acct_medicareedge", captured_at: "2026-07-14T15:38:22Z", landing_page_url: "https://medicare-help.example.com/enroll", campaign: "medicare-email", first_name: "Grace", last_name: "Adeyemi", email: "grace.adeyemi@nо-such-domain.example", phone: "+13055550135", ip_address: "72.229.28.185", user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", trusted_form_cert_url: "https://cert.trustedform.example/0011aabb22cc33dd44ee55ff66778899", form_dwell_ms: 26540, expected_verdict: "REVIEW" },
  { lead_id: "L-1009", account_id: "acct_autoinsure", captured_at: "2026-07-14T15:44:09Z", landing_page_url: "https://auto-quotes.example.com/start", campaign: "auto-affiliate-xyz", first_name: "Marcus", last_name: "Hill", email: "marcus.hill.24@gmail.com", phone: "+15125550157", ip_address: "156.146.59.22", user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", trusted_form_cert_url: "https://cert.trustedform.example/1122aabb33cc44dd55ee66ff77889900", form_dwell_ms: 9200, expected_verdict: "REJECT" },
  { lead_id: "L-1010", account_id: "acct_solarpro", captured_at: "2026-07-14T15:49:53Z", landing_page_url: "https://solar-savings.example.com/quote", campaign: "solar-affiliate-abc", first_name: "Sofia", last_name: "Ramirez", email: "sofia.ramirez@gmail.com", phone: "+19495550181", ip_address: "108.30.19.77", user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", trusted_form_cert_url: "https://cert.trustedform.example/EXPIRED-2233bb44cc55dd66ee77ff88", form_dwell_ms: 33110, expected_verdict: "REJECT" },
  { lead_id: "L-1011", account_id: "acct_medicareedge", captured_at: "2026-07-14T15:55:38Z", landing_page_url: "https://medicare-help.example.com/enroll", campaign: "medicare-native", first_name: "James", last_name: "O'Brien", email: "james.obrien@gmail.com", phone: "+12145550149", ip_address: "162.207.88.30", user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", trusted_form_cert_url: "https://cert.trustedform.example/3344cc55dd66ee77ff8899001122aabb", form_dwell_ms: 29870, expected_verdict: "REVIEW" },
  { lead_id: "L-1012", account_id: "acct_autoinsure", captured_at: "2026-07-14T16:01:20Z", landing_page_url: "https://auto-quotes.example.com/start", campaign: "auto-google-search", first_name: "Emily", last_name: "Watson", email: "emily.watson@gmail.com", phone: "+16465550193", ip_address: "74.88.140.51", user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", trusted_form_cert_url: "https://cert.trustedform.example/4455dd66ee77ff889900112233aabbcc", form_dwell_ms: 55340, expected_verdict: "ACCEPT" }
].freeze

results = LEADS.map do |attrs|
  expected = attrs.fetch(:expected_verdict)
  existing = Lead.find_by(lead_id: attrs[:lead_id])

  if existing
    run = existing.verification_run
    { lead_id: attrs[:lead_id], expected: expected, actual: run&.verdict, score: run&.score }
  else
    account = accounts.fetch(attrs.fetch(:account_id))
    lead = Lead.create!(
      account: account, pixel: pixels.fetch(attrs.fetch(:account_id)),
      lead_id: attrs[:lead_id], first_name: attrs[:first_name], last_name: attrs[:last_name],
      email: attrs[:email], phone: attrs[:phone], ip_address: attrs[:ip_address],
      user_agent: attrs[:user_agent], landing_page_url: attrs[:landing_page_url],
      trusted_form_cert_url: attrs[:trusted_form_cert_url], form_dwell_ms: attrs[:form_dwell_ms],
      captured_at: attrs[:captured_at]
    )
    run = Verification::Runner.call(lead, async: false)
    run.reload
    { lead_id: attrs[:lead_id], expected: expected, actual: run.verdict, score: run.score }
  end
end

puts "\n== Verdict summary (expected hint vs. derived) =="
printf("  %-8s %-18s %-10s %-8s %s\n", "Lead", "Expected (hint)", "Derived", "Score", "")
results.each do |r|
  match = r[:expected].sub("_DUPLICATE", "").downcase == r[:actual].to_s ? "match" : "DIVERGED"
  printf("  %-8s %-18s %-10s %-8s %s\n", r[:lead_id], r[:expected], r[:actual], r[:score]&.round(3), match)
end

diverged = results.reject { |r| r[:expected].sub("_DUPLICATE", "").downcase == r[:actual].to_s }
if diverged.any?
  puts "\n  #{diverged.size} lead(s) diverged from their hint -- review before treating this as settled."
else
  puts "\n  All 12 leads match their expected_verdict hint."
end
