class HomeController < ApplicationController
  allow_unauthenticated_access
  layout 'public'
  
  def index; end
end
