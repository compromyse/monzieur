class DropRoleFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :role
  end
end
