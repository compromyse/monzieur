class MoveRoleFromStrToInt < ActiveRecord::Migration[8.1]
  def change
    remove_column :pantries_users, :role
    add_column :pantries_users, :role, :integer, default: 0, null: false
  end
end
