class CreateConsensusPolicies < ActiveRecord::Migration[7.2]
  def change
    create_table :consensus_policies do |t|
      t.references :account, null: true, foreign_key: true, index: { unique: true }
      t.string :name, null: false

      t.timestamps
    end

    add_index :consensus_policies, "(true)", unique: true, where: "account_id IS NULL",
      name: "index_consensus_policies_on_single_global_default"
  end
end
