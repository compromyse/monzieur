class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy

  has_and_belongs_to_many :pantries

  normalizes :username, with: ->(e) { e.strip.downcase }

  enum :role, %i[ staff admin ]
end
