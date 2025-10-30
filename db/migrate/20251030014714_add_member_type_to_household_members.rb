class AddMemberTypeToHouseholdMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :household_members, :member_type, :integer, null: false
  end
end
