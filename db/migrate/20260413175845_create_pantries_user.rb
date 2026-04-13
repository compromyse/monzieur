class CreatePantriesUser < ActiveRecord::Migration[8.1]
  def change
    create_table :pantries_users do |t|
      t.references :pantry, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "employee"

      t.index ["user_id", "pantry_id"], unique: true

      t.timestamps
    end
  end
end
