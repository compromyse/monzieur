class Admin::DashboardController < Admin::BaseController

  def index
    @pantries = Pantry.all.count
    @household_members = HouseholdMember.unscoped.count
  end
end
