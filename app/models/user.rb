class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :username, with: ->(e) { e.strip.downcase }

  enum :role, %i[ staff admin ]

  has_many :visits
end
