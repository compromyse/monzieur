class VisitsController < ApplicationController

  def new
    @visit = Visit.new
  end

  def create
    @visit = Visit.new(visit_params)

    if @visit.save
      redirect_to root_path, notice: 'Visit Logged!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def visit_params
    params.require(:visit).permit(
      :client_id,
    )
  end
end
