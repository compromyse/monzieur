class ClientsController < ApplicationController

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      redirect_to root_path, notice: 'Client Created!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def find
    query = params[:q].downcase
    json = Client.where('lower(first_name) LIKE ? OR lower(last_name) LIKE ?', query, query)
      .select(:uuid, :first_name, :last_name)
      .as_json

    render json: json
  end

  private

  def client_params
    params.require(:client).permit(
      :first_name,
      :last_name,
    )
  end
end
