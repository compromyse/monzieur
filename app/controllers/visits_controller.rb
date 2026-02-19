class VisitsController < ApplicationController
  layout 'pdf', only: [:daily_signin]

  def create
    @visit = Visit.new(visit_params)
    @visit.user_id = Current.user.id

    if @visit.save
      redirect_to dashboard_index_path, notice: 'Visit Logged!'
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

    @visits = Visit.includes(client: [ :household_members ])
      .where(created_at: date.all_day)
      .order(created_at: :desc)
  end

  def daily_signin
    if params[:date].present?
      date = Date.strptime(params[:date], "%Y-%m-%d")
    else
      date = Date.today
    end

    @visits = Visit.includes(client: [ :household_members ])
      .where(created_at: date.all_day)
      .order(created_at: :desc)

    @totals = @visits.unscope(:order).joins(client: :household_members).group(:member_type).count
  end

  private

  def visit_params
    params.require(:visit).permit(
      :client_id,
    )
  end
end
