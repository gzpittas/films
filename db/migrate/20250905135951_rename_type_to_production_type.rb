class RenameTypeToProductionType < ActiveRecord::Migration[8.0]
  def change
    rename_column :productions, :type, :production_type
  end
end
