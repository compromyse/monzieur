class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :client, null: false, foreign_key: true

      t.timestamps
    end
  end
end
