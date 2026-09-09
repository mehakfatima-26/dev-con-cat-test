class CreateLeads < ActiveRecord::Migration[7.2]
  def change
    create_table :leads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pixel, null: false, foreign_key: true
      t.references :capture_session, null: true, foreign_key: true, index: { unique: true }

      t.string :lead_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.inet :ip_address, null: false
      t.string :user_agent
      t.string :landing_page_url, null: false
      t.string :campaign
      t.string :trusted_form_cert_url
      t.integer :form_dwell_ms, null: false
      t.check_constraint "form_dwell_ms >= 0", name: "leads_form_dwell_ms_non_negative"

      t.datetime :captured_at, null: false

      t.timestamps
    end
    add_index :leads, :lead_id, unique: true
    add_index :leads, [ :account_id, :captured_at ]
    add_index :leads, [ :account_id, :email ]
    add_index :leads, [ :account_id, :phone ]
  end
end
