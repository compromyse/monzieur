class Visit < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :pantry
end
