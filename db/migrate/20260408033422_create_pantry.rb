class CreatePantry < ActiveRecord::Migration[8.1]
  def change
    create_table :pantries do |t|
      t.string :name

      t.timestamps
    end
  end
end
