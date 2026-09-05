class CreatePolicyVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :policy_versions do |t|
      t.references :consensus_policy, null: false, foreign_key: true
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      t.integer :version, null: false
      t.check_constraint "version > 0", name: "policy_versions_version_positive"

      t.jsonb :rules, null: false
      t.jsonb :thresholds, null: false

      t.text :notes

      t.timestamps
    end
    add_index :policy_versions, [ :consensus_policy_id, :version ], unique: true
  end
end
