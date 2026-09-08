class RemoveSigningSecretFromPixels < ActiveRecord::Migration[7.2]
  def change
    remove_column :pixels, :signing_secret, :string, null: false
  end
end
