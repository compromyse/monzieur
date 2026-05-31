class BulkController < ApplicationController

  def intake_form
    clients = Client.all
    render partial: 'clients/intake_form', collection: clients, as: :client, spacer_template: 'new_page'
  end
end
