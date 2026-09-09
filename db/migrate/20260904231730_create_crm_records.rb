class CreateCrmRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_records do |t|
      t.references :account, null: false, foreign_key: true
      t.references :lead, null: true, foreign_key: true, index: { unique: true }

      t.string :crm_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.datetime :crm_created_at, null: false
      t.timestamps
    end
    add_index :crm_records, [ :account_id, :crm_id ], unique: true
    add_index :crm_records, [ :account_id, :phone ]
    add_index :crm_records, [ :account_id, :email ]
  end
end
