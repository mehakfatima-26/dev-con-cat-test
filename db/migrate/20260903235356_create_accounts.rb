class CreateAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.string :account_id, null: false                       
      t.string :company_name, null: false

      t.integer :plan, null: false, default: 0                 
      t.check_constraint "plan BETWEEN 0 AND 2", name: "accounts_plan_within_enum_range"

      t.integer :status, null: false, default: 0               
      t.check_constraint "status BETWEEN 0 AND 2", name: "accounts_status_within_enum_range"

      t.integer :monthly_credit_allowance, null: false, default: 0
      t.check_constraint "monthly_credit_allowance >= 0", name: "accounts_monthly_credit_allowance_non_negative"

      t.date :cycle_start, null: false
      t.date :cycle_end, null: false
      t.check_constraint "cycle_end > cycle_start", name: "accounts_cycle_end_after_cycle_start" 

      t.integer :avg_daily_burn, null: false, default: 0        
      t.check_constraint "avg_daily_burn >= 0", name: "accounts_avg_daily_burn_non_negative"

      t.string :billing_contact
      t.string :enabled_modules, array: true, null: false, default: []

      t.timestamps
    end
    add_index :accounts, :account_id, unique: true
  end
end
