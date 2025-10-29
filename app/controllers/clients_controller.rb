class ClientsController < ApplicationController

  def new
    @client = Client.new
  end

  def create
    debugger
  end
end
