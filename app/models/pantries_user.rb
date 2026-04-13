class PantriesUser < ApplicationRecord
  belongs_to :user
  belongs_to :pantry
end
