class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :user_id, null: false                          
      t.references :account, null: true, foreign_key: true    
      t.integer :role, null: false, default: 2                
      t.string :name, null: false
      t.string :email, null: false

      t.check_constraint "(role = 0 AND account_id IS NULL) OR (role != 0 AND account_id IS NOT NULL)",
        name: "users_account_id_matches_role"

      t.timestamps
    end
    add_index :users, :user_id, unique: true
    add_index :users, :email, unique: true
  end
end
