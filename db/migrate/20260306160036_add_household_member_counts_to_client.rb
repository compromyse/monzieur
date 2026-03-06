class AddHouseholdMemberCountsToClient < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :member_counts, :jsonb, default: {}, null: false
  end
end
