class HouseholdMember < ApplicationRecord
  belongs_to :client

  #                      < 2    2-5     6-17  18-59 60+
  enum :member_type, %i[ infant toddler child adult senior ]

  MEMBER_TYPES = Hash[HouseholdMember.member_types.keys.map { |v| [v, v] } ]

  def to_json
    {
      id: id,
      first_name: first_name,
      last_name: last_name,
      mobile_number: mobile_number,
      household_members: members_to_json,
    }
  end

  private

  def members_to_json
    household_members.map { |member|
      {
        first_name: member.first_name,
        last_name: member.last_name,
        member_type: member.member_type,
      }
    }
  end

end
