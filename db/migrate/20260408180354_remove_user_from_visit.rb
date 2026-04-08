class RemoveUserFromVisit < ActiveRecord::Migration[8.1]
  def change
    remove_column :visits, :user_id, :bigint
  end
end
