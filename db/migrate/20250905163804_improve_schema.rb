# db/migrate/20250905_improve_schema.rb
class ImproveSchema < ActiveRecord::Migration[8.0]
  def up
    # Remove the direct production_id from companies (we'll use junction table)
    remove_foreign_key :companies, :productions if foreign_key_exists?(:companies, :productions)
    remove_column :companies, :production_id if column_exists?(:companies, :production_id)
    
    # Remove phone and email strings from companies (we'll normalize these)
    remove_column :companies, :phones if column_exists?(:companies, :phones)
    remove_column :companies, :emails if column_exists?(:companies, :emails)
    
    # Create junction table for production-company relationships
    create_table :production_companies do |t|
      t.references :production, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :relationship_type # e.g., "Production Company", "Distributor", etc.
      t.timestamps
    end
    
    # Create separate email addresses table
    create_table :email_addresses do |t|
      t.string :email, null: false
      t.string :email_type, default: 'primary' # primary, secondary, etc.
      t.references :person, null: true, foreign_key: true
      t.references :company, null: true, foreign_key: true
      t.timestamps
    end
    
    # Create separate phone numbers table
    create_table :phone_numbers do |t|
      t.string :number, null: false
      t.string :phone_type, default: 'office' # office, mobile, fax
      t.references :person, null: true, foreign_key: true
      t.references :company, null: true, foreign_key: true
      t.timestamps
    end
    
    # Add validation that email/phone must belong to either person OR company
    add_check_constraint :email_addresses, 
      '(person_id IS NOT NULL AND company_id IS NULL) OR (person_id IS NULL AND company_id IS NOT NULL)',
      name: 'email_belongs_to_person_or_company'
    
    add_check_constraint :phone_numbers,
      '(person_id IS NOT NULL AND company_id IS NULL) OR (person_id IS NULL AND company_id IS NOT NULL)',
      name: 'phone_belongs_to_person_or_company'
    
    # Add indexes for performance
    add_index :email_addresses, :email
    add_index :phone_numbers, :number
    add_index :production_companies, [:production_id, :company_id], unique: true
    add_index :companies, :name
    add_index :people, :name
    add_index :productions, :title
    add_index :productions, :status
  end
  
  def down
    # Reverse the changes
    drop_table :production_companies
    drop_table :email_addresses
    drop_table :phone_numbers
    
    # Add back the old columns
    add_reference :companies, :production, foreign_key: true
    add_column :companies, :phones, :string
    add_column :companies, :emails, :string
  end
end