class LinkPantriesAndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :pantries_users, id: false do |t|
      t.belongs_to :pantry
      t.belongs_to :user
    end
  end
end
