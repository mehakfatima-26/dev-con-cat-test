class AddDetailAndResultToLayerResults < ActiveRecord::Migration[7.2]
  def change
    add_column :layer_results, :detail, :text, null: false
    add_column :layer_results, :result, :integer
  end
end
