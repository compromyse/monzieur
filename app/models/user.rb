class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :visits

  has_many :pantries_user
  has_many :pantries, through: :pantries_user

  normalizes :username, with: ->(e) { e.strip.downcase }

  def owner?
    Current.pantries_user.role == "owner"
  end

  def admin?
    Current.pantries_user.role == "admin" or owner?
  end
end
