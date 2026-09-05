# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_09_04_231730) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_id", null: false
    t.string "company_name", null: false
    t.integer "plan", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "monthly_credit_allowance", default: 0, null: false
    t.date "cycle_start", null: false
    t.date "cycle_end", null: false
    t.integer "avg_daily_burn", default: 0, null: false
    t.string "billing_contact"
    t.string "enabled_modules", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_accounts_on_account_id", unique: true
    t.check_constraint "avg_daily_burn >= 0", name: "accounts_avg_daily_burn_non_negative"
    t.check_constraint "cycle_end > cycle_start", name: "accounts_cycle_end_after_cycle_start"
    t.check_constraint "monthly_credit_allowance >= 0", name: "accounts_monthly_credit_allowance_non_negative"
    t.check_constraint "plan >= 0 AND plan <= 2", name: "accounts_plan_within_enum_range"
    t.check_constraint "status >= 0 AND status <= 2", name: "accounts_status_within_enum_range"
  end

  create_table "capture_sessions", force: :cascade do |t|
    t.bigint "pixel_id", null: false
    t.bigint "account_id", null: false
    t.string "session_id", null: false
    t.string "page_url", null: false
    t.string "referrer"
    t.inet "visit_ip", null: false
    t.string "user_agent"
    t.datetime "started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_capture_sessions_on_account_id"
    t.index ["pixel_id"], name: "index_capture_sessions_on_pixel_id"
    t.index ["session_id"], name: "index_capture_sessions_on_session_id", unique: true
  end

  create_table "certificates", force: :cascade do |t|
    t.bigint "verification_run_id", null: false
    t.string "serial", null: false
    t.jsonb "payload", null: false
    t.string "payload_sha256", null: false
    t.string "prev_sha256"
    t.string "signature", null: false
    t.boolean "incomplete", default: false, null: false
    t.string "incomplete_reason"
    t.datetime "issued_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial"], name: "index_certificates_on_serial", unique: true
    t.index ["verification_run_id"], name: "index_certificates_on_verification_run_id", unique: true
  end

  create_table "consensus_policies", force: :cascade do |t|
    t.bigint "account_id"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "active_policy_version_id"
    t.index "(true)", name: "index_consensus_policies_on_single_global_default", unique: true, where: "(account_id IS NULL)"
    t.index ["account_id"], name: "index_consensus_policies_on_account_id", unique: true
    t.index ["active_policy_version_id"], name: "index_consensus_policies_on_active_policy_version_id"
  end

  create_table "credit_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "verification_run_id", null: false
    t.string "layer_key", null: false
    t.integer "amount", null: false
    t.string "idempotency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_credit_transactions_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_credit_transactions_on_account_id"
    t.index ["idempotency_key"], name: "index_credit_transactions_on_idempotency_key", unique: true
    t.index ["verification_run_id"], name: "index_credit_transactions_on_verification_run_id"
    t.check_constraint "amount < 0", name: "credit_transactions_amount_negative"
  end

  create_table "crm_records", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "lead_id"
    t.string "crm_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.datetime "crm_created_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "crm_id"], name: "index_crm_records_on_account_id_and_crm_id", unique: true
    t.index ["account_id", "email"], name: "index_crm_records_on_account_id_and_email"
    t.index ["account_id", "phone"], name: "index_crm_records_on_account_id_and_phone"
    t.index ["account_id"], name: "index_crm_records_on_account_id"
    t.index ["lead_id"], name: "index_crm_records_on_lead_id", unique: true
  end

  create_table "layer_results", force: :cascade do |t|
    t.bigint "verification_run_id", null: false
    t.string "layer_key", null: false
    t.integer "state", default: 0, null: false
    t.jsonb "raw_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["verification_run_id", "layer_key"], name: "index_layer_results_on_verification_run_id_and_layer_key", unique: true
    t.index ["verification_run_id"], name: "index_layer_results_on_verification_run_id"
  end

  create_table "leads", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "pixel_id", null: false
    t.bigint "capture_session_id"
    t.string "lead_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.inet "ip_address", null: false
    t.string "user_agent"
    t.string "landing_page_url", null: false
    t.string "campaign"
    t.string "trusted_form_cert_url"
    t.integer "form_dwell_ms", null: false
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "captured_at"], name: "index_leads_on_account_id_and_captured_at"
    t.index ["account_id", "email"], name: "index_leads_on_account_id_and_email"
    t.index ["account_id", "phone"], name: "index_leads_on_account_id_and_phone"
    t.index ["account_id"], name: "index_leads_on_account_id"
    t.index ["capture_session_id"], name: "index_leads_on_capture_session_id", unique: true
    t.index ["lead_id"], name: "index_leads_on_lead_id", unique: true
    t.index ["pixel_id"], name: "index_leads_on_pixel_id"
    t.check_constraint "form_dwell_ms >= 0", name: "leads_form_dwell_ms_non_negative"
  end

  create_table "pixels", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "pixel_id", null: false
    t.string "name", null: false
    t.string "signing_secret", null: false
    t.string "allowed_origins", default: [], null: false, array: true
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_pixels_on_account_id", unique: true
    t.index ["pixel_id"], name: "index_pixels_on_pixel_id", unique: true
    t.check_constraint "status >= 0 AND status <= 1", name: "pixels_status_within_enum_range"
  end

  create_table "policy_versions", force: :cascade do |t|
    t.bigint "consensus_policy_id", null: false
    t.bigint "created_by_id"
    t.integer "version", null: false
    t.jsonb "rules", null: false
    t.jsonb "thresholds", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consensus_policy_id", "version"], name: "index_policy_versions_on_consensus_policy_id_and_version", unique: true
    t.index ["consensus_policy_id"], name: "index_policy_versions_on_consensus_policy_id"
    t.index ["created_by_id"], name: "index_policy_versions_on_created_by_id"
    t.check_constraint "version > 0", name: "policy_versions_version_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "user_id", null: false
    t.bigint "account_id"
    t.integer "role", default: 2, null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["user_id"], name: "index_users_on_user_id", unique: true
    t.check_constraint "role = 0 AND account_id IS NULL OR role <> 0 AND account_id IS NOT NULL", name: "users_account_id_matches_role"
  end

  create_table "verification_runs", force: :cascade do |t|
    t.bigint "lead_id", null: false
    t.bigint "policy_version_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "verdict"
    t.string "verdict_reason"
    t.decimal "score", precision: 5, scale: 4
    t.jsonb "reasons", default: [], null: false
    t.integer "credits_charged", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_verification_runs_on_lead_id", unique: true
    t.index ["policy_version_id"], name: "index_verification_runs_on_policy_version_id"
    t.check_constraint "(status = ANY (ARRAY[2, 3])) AND verdict IS NOT NULL OR (status = ANY (ARRAY[0, 1])) AND verdict IS NULL", name: "verification_runs_verdict_matches_status"
    t.check_constraint "credits_charged >= 0", name: "verification_runs_credits_charged_non_negative"
  end

  add_foreign_key "capture_sessions", "accounts"
  add_foreign_key "capture_sessions", "pixels"
  add_foreign_key "certificates", "verification_runs"
  add_foreign_key "consensus_policies", "accounts"
  add_foreign_key "consensus_policies", "policy_versions", column: "active_policy_version_id"
  add_foreign_key "credit_transactions", "accounts"
  add_foreign_key "credit_transactions", "verification_runs"
  add_foreign_key "crm_records", "accounts"
  add_foreign_key "crm_records", "leads"
  add_foreign_key "layer_results", "verification_runs"
  add_foreign_key "leads", "accounts"
  add_foreign_key "leads", "capture_sessions"
  add_foreign_key "leads", "pixels"
  add_foreign_key "pixels", "accounts"
  add_foreign_key "policy_versions", "consensus_policies"
  add_foreign_key "policy_versions", "users", column: "created_by_id"
  add_foreign_key "users", "accounts"
  add_foreign_key "verification_runs", "leads"
  add_foreign_key "verification_runs", "policy_versions"
end
