class HouseholdMember < ApplicationRecord
  belongs_to :client
  belongs_to :pantry

  MEMBER_TYPES = {
    infant: 'Infant (< 2)',
    toddler: 'Toddler (2-5)',
    child: 'Child (6-17)',
    adult: 'Adult (18-59)',
    senior: 'Senior (60+)',
  }
end
