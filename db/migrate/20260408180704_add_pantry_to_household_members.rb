class AddPantryToHouseholdMembers < ActiveRecord::Migration[8.1]
  def change
    add_reference :household_members, :pantry, null: false, foreign_key: true
  end
end
