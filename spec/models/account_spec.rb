require "rails_helper"

RSpec.describe Account do
  it "has a valid factory" do
    expect(build(:account)).to be_valid
  end

  it "requires a unique account_id" do
    create(:account, account_id: "acct_dupe")
    dupe = build(:account, account_id: "acct_dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:account_id]).to be_present
  end

  it "requires company_name" do
    account = build(:account, company_name: nil)

    expect(account).not_to be_valid
  end

  it "requires billing_contact" do
    account = build(:account, billing_contact: nil)

    expect(account).not_to be_valid
  end

  it "exposes the plan tiers from the seed data" do
    expect(Account.plans.keys).to contain_exactly("starter", "growth", "enterprise")
  end

  it "exposes the account statuses from the seed data" do
    expect(Account.statuses.keys).to contain_exactly("active", "past_due", "suspended")
  end

  it "rejects a negative monthly credit allowance" do
    account = build(:account, monthly_credit_allowance: -1)

    expect(account).not_to be_valid
  end

  it "rejects cycle_end before cycle_start" do
    account = build(:account, cycle_start: Date.current, cycle_end: Date.current - 1)

    expect(account).not_to be_valid
    expect(account.errors[:cycle_end]).to be_present
  end

  it "rejects an unknown enabled_module" do
    account = build(:account, enabled_modules: %w[anura not_a_real_layer])

    expect(account).not_to be_valid
    expect(account.errors[:enabled_modules]).to be_present
  end

  it "accepts every known layer key as an enabled_module" do
    account = build(:account, enabled_modules: DetectionLayer::KEYS)

    expect(account).to be_valid
  end

  describe "credits_used_this_cycle and credits_remaining" do
    it "reproduces the seed data's own arithmetic (allowance - used = remaining)" do
      account = create(:account, monthly_credit_allowance: 25_000)
      run = create(:verification_run, lead: create(:lead, pixel: create(:pixel, account: account), account: account))
      create(:credit_transaction, account: account, verification_run: run, layer_key: "enrichment", amount: -21_840)

      expect(account.credits_used_this_cycle).to eq(21_840)
      expect(account.credits_remaining).to eq(3_160)
    end

    it "ignores transactions from a previous cycle" do
      account = create(:account, monthly_credit_allowance: 25_000)
      run = create(:verification_run, lead: create(:lead, pixel: create(:pixel, account: account), account: account))
      old_charge = create(:credit_transaction, account: account, verification_run: run, layer_key: "voice", amount: -500)
      old_charge.update_column(:created_at, account.cycle_start - 1.day)

      expect(account.credits_used_this_cycle).to eq(0)
      expect(account.credits_remaining).to eq(25_000)
    end
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:base_attrs) do
      {
        account_id: "acct_db_constraint_test", company_name: "Evil Co",
        plan: 0, status: 0, monthly_credit_allowance: 100,
        cycle_start: Date.current, cycle_end: Date.current + 30,
        avg_daily_burn: 0, enabled_modules: "{}",
        created_at: Time.current, updated_at: Time.current
      }
    end

    it "rejects a negative monthly_credit_allowance at the DB level" do
      expect {
        Account.insert_all!([ base_attrs.merge(monthly_credit_allowance: -500) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /accounts_monthly_credit_allowance_non_negative/)
    end

    it "rejects a negative avg_daily_burn at the DB level" do
      expect {
        Account.insert_all!([ base_attrs.merge(avg_daily_burn: -1) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /accounts_avg_daily_burn_non_negative/)
    end

    it "rejects an out-of-range plan at the DB level" do
      expect {
        Account.insert_all!([ base_attrs.merge(plan: 99) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /accounts_plan_within_enum_range/)
    end

    it "rejects an out-of-range status at the DB level" do
      expect {
        Account.insert_all!([ base_attrs.merge(status: 99) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /accounts_status_within_enum_range/)
    end

    it "rejects cycle_end before cycle_start at the DB level" do
      expect {
        Account.insert_all!([ base_attrs.merge(cycle_end: Date.current - 5) ])
      }.to raise_error(ActiveRecord::StatementInvalid, /accounts_cycle_end_after_cycle_start/)
    end

    it "rejects a duplicate account_id at the DB level" do
      Account.insert_all!([ base_attrs ])

      expect {
        Account.insert_all!([ base_attrs.merge(company_name: "Different Co") ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
