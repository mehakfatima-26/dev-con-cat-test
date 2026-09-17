class AddCreditsReservedToVerificationRuns < ActiveRecord::Migration[7.2]
  def change
    add_column :verification_runs, :credits_reserved, :integer, null: false, default: 0
  end
end
