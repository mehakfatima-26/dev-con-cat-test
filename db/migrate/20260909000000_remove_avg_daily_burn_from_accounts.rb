class RemoveAvgDailyBurnFromAccounts < ActiveRecord::Migration[7.2]
  def change
    remove_column :accounts, :avg_daily_burn, :integer, default: 0, null: false
  end
end
