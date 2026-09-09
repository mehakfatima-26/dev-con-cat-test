class AddExactMatchIndexToCrmRecords < ActiveRecord::Migration[7.2]
  def change
    add_index :crm_records, [ :account_id, :phone, :email ], unique: true,
      name: "index_crm_records_on_account_phone_email_exact_match"
  end
end
