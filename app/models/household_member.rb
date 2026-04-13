class HouseholdMember < ApplicationRecord
  belongs_to :client
  belongs_to :pantry

  before_validation :assign_pantry, on: :create

  MEMBER_TYPES = {
    infant: 'Infant (< 2)',
    toddler: 'Toddler (2-5)',
    child: 'Child (6-17)',
    adult: 'Adult (18-59)',
    senior: 'Senior (60+)',
  }

  default_scope { where(pantry_id: Current.pantry&.id).distinct }

  private

  def assign_pantry
    self.pantry ||= Current.pantry
  end
end
