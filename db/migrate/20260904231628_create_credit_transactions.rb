class CreateCreditTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :credit_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :verification_run, null: false, foreign_key: true
      t.string :layer_key, null: false
      t.integer :amount, null: false 
      t.string :idempotency_key, null: false 

      t.check_constraint "amount < 0", name: "credit_transactions_amount_negative"

      t.timestamps
    end
    add_index :credit_transactions, :idempotency_key, unique: true
    add_index :credit_transactions, [ :account_id, :created_at ]
  end
end
