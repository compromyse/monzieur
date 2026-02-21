class AddZipcodeToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :zipcode, :string, null: false
  end
end
