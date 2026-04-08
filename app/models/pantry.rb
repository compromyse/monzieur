class Pantry < ApplicationRecord
  has_and_belongs_to_many :user
end
