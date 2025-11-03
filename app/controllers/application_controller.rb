class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
  
  def admin_only!
    if not Current.user.admin?
      redirect_to dashboard_index_path, alert: 'Admin access only!'
    end
  end
end
