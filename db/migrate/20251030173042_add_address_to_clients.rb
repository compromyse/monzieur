class AddAddressToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :address, :string
  end
end
