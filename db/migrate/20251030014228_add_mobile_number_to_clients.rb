class AddMobileNumberToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :mobile_number, :string, null: false
  end
end
