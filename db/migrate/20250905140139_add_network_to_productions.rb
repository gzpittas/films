class AddNetworkToProductions < ActiveRecord::Migration[8.0]
  def change
    add_column :productions, :network, :string
  end
end
