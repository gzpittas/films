class AddTypeToProductions < ActiveRecord::Migration[8.0]
  def change
    add_column :productions, :type, :string
  end
end
