class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_pantry

  private
  
  def admin_only!
    if not Current.user.admin?
      redirect_to root_path, alert: 'Admin access only!'
    end
  end

  def set_pantry
    Current.pantry ||= Pantry.find_by(id: params[:pantry_id])
  end

  def default_url_options
    { pantry_id: Current.pantry&.id }
  end
end
