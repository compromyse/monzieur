class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_user_path, alert: "Try again later." }

  def new
  end

  def create
    user = User.new(user_params)
    if user.save
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_user_path, alert: "Error creating user, maybe the username is taken?"
    end
  end

  private

  def user_params
    params.permit(
      :username,
      :password
    )
  end
end
