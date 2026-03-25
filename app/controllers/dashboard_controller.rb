class DashboardController < ApplicationController
  
  def index
    @visit_count = Visit.where(created_at: Time.current.all_day).count
  end
end
