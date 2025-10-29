class UsersController < ApplicationController
  before_action :admin_only!

  def new
    @user = User.new
  end

  def create
    user = User.new(user_params)

    if user.save
      return redirect_to root_path, notice: 'User Created!'
    end

    redirect_to root_path, alert: 'Unable to Create User.'
  end

  private

  def user_params
    params.require(:user).permit(
      :email_address,
      :password,
    )
  end
end
