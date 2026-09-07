class AllowMultipleVerificationRunsPerLead < ActiveRecord::Migration[7.2]
  def change
    remove_index :verification_runs, :lead_id, unique: true
    add_index :verification_runs, :lead_id
  end
end
