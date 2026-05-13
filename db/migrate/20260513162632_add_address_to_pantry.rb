class AddAddressToPantry < ActiveRecord::Migration[8.1]
  def change
    add_column :pantries, :address, :string, null: false, default: ''
  end
end
