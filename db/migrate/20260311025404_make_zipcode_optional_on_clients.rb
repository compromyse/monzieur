class MakeZipcodeOptionalOnClients < ActiveRecord::Migration[8.1]
  def change
    change_column_null :clients, :zipcode, true
  end
end
