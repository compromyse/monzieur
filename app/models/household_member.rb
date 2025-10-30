class HouseholdMember < ApplicationRecord
  belongs_to :client

  #                      < 2    2-5     6-17  18-59 60+
  enum :member_type, %i[ infant toddler child adult senior ]

  MEMBER_TYPES = Hash[HouseholdMember.member_types.keys.map { |v| [v, v] } ]
end
