class ClientsController < ApplicationController
  layout 'pdf', only: [:intake_form]

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      redirect_to dashboard_index_path, notice: 'Client Created!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @client = Client
                .includes(:household_members)
                .find_by(uuid: params[:uuid])

    if @client.nil?
      return redirect_back fallback_location: dashboard_index_path, alert: 'Client not found!'
    end
  end

  def edit
    @client = Client.find(params[:id])
  end

  def update
    @client = Client.find(params[:id])
    if @client.update(client_params)
      redirect_to show_clients_path(uuid: @client.uuid), notice: 'Client Updated!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def find
    q = params[:q]
    json = Client.where('lower(first_name) LIKE ? OR lower(last_name) LIKE ? OR mobile_number = ?', q.downcase + '%', q.downcase+ '%', q)
      .limit(10)
      .select(:uuid, :first_name, :last_name, :mobile_number)
      .as_json

    render json: json
  end

  def visit_history
    client = Client.find_by(uuid: params[:uuid])
    @visits = client.visit_history
  end

  def intake_form
    @client = Client
                .includes(:household_members, visits: [ :user ])
                .find_by(uuid: params[:uuid])

    if @client.nil?
      return redirect_back fallback_location: dashboard_index_path, alert: 'Client not found!'
    end

    @household_member_counts = @client.household_members.group(:member_type).count
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
        :id,
        :_destroy,
      ],
    )
  end
end
