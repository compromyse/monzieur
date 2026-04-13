class Pantry < ApplicationRecord
  has_many :household_members
  has_many :visits
  has_many :clients

  has_many :pantries_user
  has_many :users, through: :pantries_user

  default_scope { joins(:pantries_user).where(pantries_user: { user_id: Current.user&.id }).distinct }

  after_create :assign_user

  def assign_user
    Current.user.pantries << self
    PantriesUser.find_by(user_id: Current.user.id, pantry_id: self.id).update(role: :owner)
  end
end
