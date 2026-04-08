class AddPantryToClients < ActiveRecord::Migration[8.1]
  def change
    add_reference :clients, :pantry, null: false, foreign_key: true
  end
end
