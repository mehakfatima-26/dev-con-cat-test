class CreateCaptureSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :capture_sessions do |t|
      t.references :pixel, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true

      t.string :session_id, null: false
      t.string :page_url, null: false
      t.string :referrer
      t.inet :visit_ip, null: false
      t.string :user_agent 
      t.datetime :started_at, null: false

      t.timestamps
    end
    add_index :capture_sessions, :session_id, unique: true
  end
end
