class ImportsController < ApplicationController
  
  def import_csv_form; end

  def import_csv
    full = params[:full_list].tempfile.path
    clients = params[:clients].tempfile.path

    num = Import.new.import_from_csvs(full, clients)
    redirect_to import_csv_form_imports_path, notice: "Imported #{num} clients!"
  end
end
