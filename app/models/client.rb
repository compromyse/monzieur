class Client < ApplicationRecord
  has_many :visits
  has_many :household_members
end
