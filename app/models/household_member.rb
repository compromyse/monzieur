class HouseholdMember < ApplicationRecord
  belongs_to :client

  #                      < 2    2-5     6-17  18-59 60+
  enum :member_type, %i[ infant toddler child adult senior ]

  MEMBER_TYPES = {
    infant: 'Infant (< 2)',
    toddler: 'Toddler (2-5)',
    child: 'Child (6-17)',
    adult: 'Adult (18-59)',
    senior: 'Senior (60+)',
  }
end
