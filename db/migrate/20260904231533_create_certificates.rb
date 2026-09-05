class CreateCertificates < ActiveRecord::Migration[7.2]
  def change
    create_table :certificates do |t|
      t.references :verification_run, null: false, foreign_key: true, index: { unique: true }

      t.string :serial, null: false

      # Canonical signed content: verdict, score, reasons, policy version
      # identity, per-layer summary, and the lead's trusted_form_cert_url --
      # everything a buyer would need to defend this lead later.
      t.jsonb :payload, null: false
      t.string :payload_sha256, null: false
      t.string :prev_sha256
      t.string :signature, null: false

      t.boolean :incomplete, null: false, default: false
      t.string :incomplete_reason

      t.datetime :issued_at, null: false

      t.timestamps
    end
    add_index :certificates, :serial, unique: true
  end
end
