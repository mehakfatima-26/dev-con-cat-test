class CreateLayerResults < ActiveRecord::Migration[7.2]
  def change
    create_table :layer_results do |t|
      t.references :verification_run, null: false, foreign_key: true
      t.string :layer_key, null: false
      t.integer :state, null: false, default: 0 # enum: not_enabled/not_applicable/completed/errored/skipped
      t.jsonb :raw_response
      t.timestamps
    end
    add_index :layer_results, [ :verification_run_id, :layer_key ], unique: true
  end
end
