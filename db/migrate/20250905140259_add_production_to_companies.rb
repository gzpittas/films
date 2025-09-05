class AddProductionToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_reference :companies, :production, null: true, foreign_key: true
  end
end