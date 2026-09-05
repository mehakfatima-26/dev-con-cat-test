class AddActivePolicyVersionToConsensusPolicies < ActiveRecord::Migration[7.2]
  def change
    add_reference :consensus_policies, :active_policy_version, null: true,
      foreign_key: { to_table: :policy_versions }
  end
end
