class BulkController < ApplicationController
  layout 'pdf'

  def intake_form
    @clients = Client.all
  end
end
