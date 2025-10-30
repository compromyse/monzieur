class AddIndexToNameAndMobileNumberOnClients < ActiveRecord::Migration[8.1]
  def change
    add_index :clients, :first_name
    add_index :clients, :last_name
    add_index :clients, :mobile_number, unique: true
  end
end
