class MakeIndexNonUniqueOnMobileNumber < ActiveRecord::Migration[8.1]
  def change
    remove_index :clients, :mobile_number, unique: true
    add_index :clients, :mobile_number, unique: false
  end
end
