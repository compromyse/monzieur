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

  def show
    @client = Client.includes(:household_members).find_by(uuid: params[:uuid])

    if @client.nil?
      redirect_back fallback_location: root_path, alert: 'Client not found!'
    end
  end

  def find
    query = params[:q].downcase
    json = Client.where('lower(first_name) LIKE ? OR lower(last_name) LIKE ? OR mobile_number = ?', query, query, query)
      .select(:uuid, :first_name, :last_name, :mobile_number)
      .as_json

    render json: json
  end

  private

  def client_params
    params.require(:client).permit(
      :first_name,
      :last_name,
      :mobile_number,
      :address,
      :notes,
      household_members_attributes: [
        :first_name,
        :last_name,
        :member_type,
      ],
    )
  end
end
