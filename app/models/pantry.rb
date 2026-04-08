class Pantry < ApplicationRecord
  has_and_belongs_to_many :user

  has_many :household_members
  has_many :visits
  has_many :clients

  default_scope { joins(:user).where(users: { id: Current.user.id }).distinct }
end
