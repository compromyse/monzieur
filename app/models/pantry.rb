class Pantry < ApplicationRecord
  has_many :household_members
  has_many :visits
  has_many :clients

  has_many :pantries_user
  has_many :users, through: :pantries_user

  default_scope { joins(:pantries_user).where(pantries_user: { user_id: Current.user&.id }).distinct }
end
