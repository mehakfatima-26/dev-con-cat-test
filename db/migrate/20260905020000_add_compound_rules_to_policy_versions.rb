class AddCompoundRulesToPolicyVersions < ActiveRecord::Migration[7.2]
  def change
    add_column :policy_versions, :compound_rules, :jsonb, null: false, default: []
  end
end
