class CreateProductions < ActiveRecord::Migration[8.0]
  def change
    create_table :productions do |t|
      t.string :title
      t.string :status
      t.string :location

      t.timestamps
    end
  end
end
