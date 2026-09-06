class AddEnabledModulesSnapshotToVerificationRuns < ActiveRecord::Migration[7.2]
  def change
    add_column :verification_runs, :enabled_modules_snapshot, :string, array: true, null: false, default: []
  end
end
