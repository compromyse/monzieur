class DontAllowNullUsersOnVisits < ActiveRecord::Migration[8.1]
  def change
    change_column_null :visits, :user_id, false
  end
end
