class CreatePixels < ActiveRecord::Migration[7.2]
  def change
    create_table :pixels do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :pixel_id, null: false                          
      t.string :name, null: false
      t.string :signing_secret, null: false
      t.string :allowed_origins, array: true, null: false, default: []
      t.integer :status, null: false, default: 0                
      t.check_constraint "status BETWEEN 0 AND 1", name: "pixels_status_within_enum_range"

      t.timestamps
    end
    add_index :pixels, :pixel_id, unique: true
  end
end
