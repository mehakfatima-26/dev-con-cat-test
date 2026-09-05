require "rails_helper"

RSpec.describe CreditTransaction do
  it "has a valid factory" do
    expect(build(:credit_transaction)).to be_valid
  end

  it "requires a unique idempotency_key" do
    create(:credit_transaction, idempotency_key: "idem_dupe")
    dupe = build(:credit_transaction, idempotency_key: "idem_dupe")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:idempotency_key]).to be_present
  end

  it "requires a verification_run" do
    expect(build(:credit_transaction, verification_run: nil)).not_to be_valid
  end

  it "requires a layer_key" do
    expect(build(:credit_transaction, layer_key: nil)).not_to be_valid
  end

  it "rejects an unknown layer_key" do
    expect(build(:credit_transaction, layer_key: "not_a_real_layer")).not_to be_valid
  end

  it "rejects a zero amount" do
    expect(build(:credit_transaction, amount: 0)).not_to be_valid
  end

  it "rejects a positive amount" do
    txn = build(:credit_transaction, amount: 2)

    expect(txn).not_to be_valid
    expect(txn.errors[:amount]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    let(:account) { create(:account) }
    let(:run) { create(:verification_run) }

    it "rejects a duplicate idempotency_key at the DB level" do
      base_attrs = {
        account_id: account.id, verification_run_id: run.id, layer_key: "anura",
        amount: -2, idempotency_key: "idem_db_test",
        created_at: Time.current, updated_at: Time.current
      }
      CreditTransaction.insert_all!([ base_attrs ])

      expect {
        CreditTransaction.insert_all!([ base_attrs.merge(amount: -3) ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a positive amount at the DB level" do
      expect {
        CreditTransaction.insert_all!([ {
          account_id: account.id, verification_run_id: run.id, layer_key: "anura",
          amount: 2, idempotency_key: "idem_db_test2",
          created_at: Time.current, updated_at: Time.current
        } ])
      }.to raise_error(ActiveRecord::StatementInvalid, /credit_transactions_amount_negative/)
    end
  end
end
