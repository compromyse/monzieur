class PantriesUser < ApplicationRecord
  belongs_to :user
  belongs_to :pantry

  enum :role, %i[ staff admin ]
end
