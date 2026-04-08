class Visit < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :pantry

  before_validation :assign_pantry, on: :create

  private

  def assign_pantry
    self.pantry = Current.pantry
  end
end
