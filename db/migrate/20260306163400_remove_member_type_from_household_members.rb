class RemoveMemberTypeFromHouseholdMembers < ActiveRecord::Migration[8.1]
  def change
    remove_column :household_members, :member_type
  end
end
