class CreateVerificationRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :verification_runs do |t|
      t.references :lead, null: false, foreign_key: true, index: { unique: true }
      t.references :policy_version, null: false, foreign_key: true
      t.integer :status, null: false, default: 0 # enum: pending/running/completed/partial
      t.integer :verdict # enum: accept/review/reject -- null until the engine finishes
      t.check_constraint "(status IN (2, 3) AND verdict IS NOT NULL) OR (status IN (0, 1) AND verdict IS NULL)",
        name: "verification_runs_verdict_matches_status"
      t.string :verdict_reason
      t.decimal :score, precision: 5, scale: 4 # null until the engine finishes
      t.jsonb :reasons, null: false, default: []

      t.integer :credits_charged, null: false, default: 0
      t.check_constraint "credits_charged >= 0", name: "verification_runs_credits_charged_non_negative"

      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end
  end
end
