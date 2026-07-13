module ApplicationHelper
  def get_title
    Current.pantry.present? ? Current.pantry.name.upcase : "Pantrie"
  end
end
