class AddEnabledModulesToPolicyVersions < ActiveRecord::Migration[7.2]
  def change
    add_column :policy_versions, :enabled_modules, :string, array: true, null: false, default: []
  end
end
