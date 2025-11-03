class IndexCreatedAtOnVisits < ActiveRecord::Migration[8.1]
  def change
    add_index :visits, :created_at
  end
end
