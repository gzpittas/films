class AddEditionNumberToProductions < ActiveRecord::Migration[7.0]
  def change
    add_column :productions, :edition_number, :integer
  end
end