class ClientsController < ApplicationController

  def new
    @client = Client.new
  end

  def create
    client = Client.new(client_params)

    if client.save
      return redirect_to root_path, notice: 'Client Created!'
    end

    redirect_to root_path, alert: 'Unable to Create Client.'
  end

  private

  def client_params
    params.require(:client).permit(
      :first_name,
      :last_name,
    )
  end
end
