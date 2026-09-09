class AddWeightToLayerResults < ActiveRecord::Migration[7.2]
  def change
    add_column :layer_results, :weight, :decimal, precision: 6, scale: 4
  end
end
