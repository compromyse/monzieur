class DashboardController < ApplicationController
  
  def index
    @visit_count = Visit.where(created_at: Date.today.all_day).count
  end
end
