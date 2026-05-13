module ApplicationHelper
  def get_title
    Current.pantry.present? ? Current.pantry.name.upcase : "Monzieur"
  end
end
