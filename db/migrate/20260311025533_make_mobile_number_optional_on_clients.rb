class MakeMobileNumberOptionalOnClients < ActiveRecord::Migration[8.1]
  def change
    change_column_null :clients, :mobile_number, true
  end
end
