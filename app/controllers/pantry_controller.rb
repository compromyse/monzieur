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

  private

  def pantry_params
    params.require(:pantry).permit(
      :name,
    )
  end
end
