class VisitsController < ApplicationController

  def create
    @visit = Visit.new(visit_params)

    if @visit.save
      redirect_to root_path, notice: 'Visit Logged!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    if params[:date].present?
      date = Date.strptime(params[:date], "%Y-%m-%d")
    else
      date = Date.today
    end

    @visits = Visit.includes(:client)
      .where(created_at: date.all_day)
      .order(created_at: :desc)
  end

  private

  def visit_params
    params.require(:visit).permit(
      :client_id,
    )
  end
end
