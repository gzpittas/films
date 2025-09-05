class AddDescriptionToProductions < ActiveRecord::Migration[8.0]
  def change
    add_column :productions, :description, :text
  end
end
