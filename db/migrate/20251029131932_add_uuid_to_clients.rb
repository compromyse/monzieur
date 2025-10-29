class AddUuidToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :uuid, :uuid, null: false, default: 'gen_random_uuid()'
  end
end
