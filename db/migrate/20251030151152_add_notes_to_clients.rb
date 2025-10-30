class AddNotesToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :notes, :string, null: false, default: ''
  end
end
