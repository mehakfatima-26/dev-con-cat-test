class RemoveEnabledModulesFromPolicyVersions < ActiveRecord::Migration[7.2]
  def change
    remove_column :policy_versions, :enabled_modules, :string, array: true, null: false, default: []
  end
end
