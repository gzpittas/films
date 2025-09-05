class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :address
      t.string :phones
      t.string :emails
      t.string :role

      t.timestamps
    end
  end
end
