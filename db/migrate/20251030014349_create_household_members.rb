class CreateHouseholdMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :household_members do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.references :client, null: false, foreign_key: true

      t.timestamps
    end
  end
end
