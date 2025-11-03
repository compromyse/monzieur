class AddIndexToUuidOnClients < ActiveRecord::Migration[8.1]
  def change
    add_index :clients, :uuid, unique: true
  end
end
