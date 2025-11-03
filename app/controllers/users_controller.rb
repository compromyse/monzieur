class UsersController < ApplicationController
  before_action :admin_only!

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to dashboard_index_path, notice: 'User Created!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :username,
      :password,
      :role,
    )
  end
end
