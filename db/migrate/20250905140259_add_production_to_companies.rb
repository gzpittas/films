class AddProductionToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_reference :companies, :production, null: false, foreign_key: true
  end
end
