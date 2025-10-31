class DropEmailAddressAndAddUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string, null: false
    remove_column :users, :email_address
  end
end
