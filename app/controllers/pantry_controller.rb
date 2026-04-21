class PantryController < ApplicationController

  def index
    @pantries = Pantry.all
  end

  def new
    @pantry = Pantry.new
  end

  def create
    @pantry = Pantry.new(pantry_params)

    if @pantry.save
      redirect_to dashboard_index_path(pantry_id: @pantry.id), notice: 'Pantry Created!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def users
    @users = Current.pantry.users
  end

  def add_user
    u = User.find_by(username: params[:username])
    if u.nil?
      redirect_to pantry_users_path, alert: 'Cannot find user with the given username.'
      return 
    end

    Current.pantry.users << u
    redirect_to pantry_users_path, notice: 'Added user.'
  end

  def remove_user
    u = User.find_by(username: params[:username])
    if u.nil?
      redirect_to pantry_users_path, alert: 'Cannot find user with the given username.'
      return 
    end

    Current.pantry.users.delete(u)
    redirect_to pantry_users_path, notice: 'Removed user.'
  end

  private

  def pantry_params
    params.require(:pantry).permit(
      :name,
    )
  end
end
