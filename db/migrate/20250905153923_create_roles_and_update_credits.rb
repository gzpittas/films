class CreateRolesAndUpdateCredits < ActiveRecord::Migration[8.0]
  def change
    # Create the new roles table
    create_table :roles do |t|
      t.string :name, null: false, index: { unique: true }
      t.timestamps
    end

    # Add the new role_id column to the credits table, allowing it to be null for now
    add_reference :credits, :role, null: true, foreign_key: true

    # Remove the old role column from the credits table
    remove_column :credits, :role, :string
  end
end
