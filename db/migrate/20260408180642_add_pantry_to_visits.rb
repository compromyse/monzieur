class AddPantryToVisits < ActiveRecord::Migration[8.1]
  def change
    add_reference :visits, :pantry, null: false, foreign_key: true
  end
end
